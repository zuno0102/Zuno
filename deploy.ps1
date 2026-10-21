<#
.SYNOPSIS
  Commit to Zuno_Dev, push to main, and deploy whatever changed: Neon, Render, Vercel.

.DESCRIPTION
  The one way Zuno ships. Repository: https://github.com/zuno0102/Zuno (never any other).

    1. Commits any uncommitted changes to Zuno_Dev (needs -Message).
    2. Works out what changed since the last deploy (origin/main).
    3. Neon   - if migrations changed, applies them BEFORE the API that needs them goes out.
    4. Pushes Zuno_Dev, then fast-forwards main to it.
    5. Render - if backend/ or render.yaml changed, triggers a deploy through the deploy hook.
    6. Vercel - if mobile/ changed, rebuilds the web app against the live API and deploys it.

  Secrets live in .env.deploy next to this script (gitignored). See deploy.env.example.

.EXAMPLE
  .\deploy.ps1 -Message "Fix logo upload on web"
.EXAMPLE
  .\deploy.ps1            # nothing to commit: just push and deploy what main is missing
.EXAMPLE
  .\deploy.ps1 -Force     # redeploy Render and Vercel even if nothing changed
.EXAMPLE
  .\deploy.ps1 -SkipMigrations   # only when you know Neon already has every migration
#>
param(
    [string]$Message,
    [switch]$Force,
    [switch]$SkipMigrations
)

# Not 'Stop': Windows PowerShell turns any stderr line from git/flutter/vercel - including harmless
# warnings - into a terminating error when output is redirected. Exit codes are checked by Run.
$ErrorActionPreference = 'Continue'
$Root = $PSScriptRoot
$RepoUrl = 'https://github.com/zuno0102/Zuno.git'
$DevBranch = 'Zuno_Dev'
$MainBranch = 'main'

function Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }
function Fail($text) { Write-Host "ERROR: $text" -ForegroundColor Red; exit 1 }
function Run($what) { if ($LASTEXITCODE -ne 0) { Fail "$what failed (exit $LASTEXITCODE)." } }

Set-Location $Root

# ---- Settings -----------------------------------------------------------------------------------
$Settings = @{ API_BASE_URL = 'https://zuno-api-qon8.onrender.com' }
$EnvFile = Join-Path $Root '.env.deploy'
if (Test-Path $EnvFile) {
    foreach ($line in Get-Content $EnvFile) {
        if ($line -match '^\s*([A-Z_]+)\s*=\s*(.*?)\s*$') { $Settings[$Matches[1]] = $Matches[2] }
    }
}

# ---- Guard rails --------------------------------------------------------------------------------
Step 'Checking repository'
$origin = git remote get-url origin
if ($origin -ne $RepoUrl) { Fail "origin is '$origin'. Zuno only ships from $RepoUrl." }
$branch = git rev-parse --abbrev-ref HEAD
if ($branch -ne $DevBranch) { Fail "On branch '$branch'. Switch to $DevBranch first." }

git fetch --quiet origin; Run 'git fetch'

# ---- 1. Commit ----------------------------------------------------------------------------------
if (git status --porcelain) {
    if (-not $Message) { Fail 'There are uncommitted changes. Pass -Message "what changed".' }
    Step "Committing to $DevBranch"
    git add -A; Run 'git add'
    $msgFile = New-TemporaryFile
    # Without a BOM: Windows PowerShell's "utf8" adds one, and git keeps it in the message.
    [IO.File]::WriteAllText($msgFile, $Message, (New-Object Text.UTF8Encoding $false))
    git commit --quiet -F $msgFile; Run 'git commit'
    Remove-Item $msgFile
}

git merge-base --is-ancestor "origin/$DevBranch" HEAD
if ($LASTEXITCODE -ne 0) { Fail "origin/$DevBranch has commits you do not. Run: git pull --rebase origin $DevBranch" }

# ---- 2. What changed since the last deploy ------------------------------------------------------
$deployed = git rev-parse "origin/$MainBranch"
$changed = @(git diff --name-only $deployed HEAD)
if (-not $changed -and -not $Force) {
    Write-Host "`nNothing new since the last deploy ($($deployed.Substring(0,7))). Use -Force to redeploy anyway." -ForegroundColor Yellow
    exit 0
}

$migrationsChanged = -not $SkipMigrations -and [bool]($changed -match '^backend/src/Zuno\.Infrastructure/Persistence/Migrations/')
$backendChanged = $Force -or [bool]($changed -match '^(backend/|render\.yaml$)')
$webChanged = $Force -or [bool]($changed -match '^mobile/(lib|web|assets)/|^mobile/pubspec\.(yaml|lock)$')

Write-Host ("Changed files: {0}  |  Neon migrations: {1}  |  Render: {2}  |  Vercel: {3}" -f `
    $changed.Count, $migrationsChanged, $backendChanged, $webChanged)

# ---- 3. Neon (before the API that depends on it) ------------------------------------------------
if ($migrationsChanged) {
    Step 'Neon: applying database migrations'
    if (-not $Settings.NEON_CONNECTION_STRING) { Fail 'Migrations changed but NEON_CONNECTION_STRING is not set in .env.deploy.' }
    $env:ConnectionStrings__ZunoDatabase = $Settings.NEON_CONNECTION_STRING
    try {
        Push-Location (Join-Path $Root 'backend')
        dotnet ef database update --project src/Zuno.Infrastructure --startup-project src/Zuno.Api; Run 'dotnet ef database update'
    } finally {
        Pop-Location
        Remove-Item Env:\ConnectionStrings__ZunoDatabase -ErrorAction SilentlyContinue
    }
}

# ---- 4. Push ------------------------------------------------------------------------------------
Step "Pushing $DevBranch and fast-forwarding $MainBranch"
git push --quiet origin $DevBranch; Run "git push $DevBranch"
git push --quiet origin "${DevBranch}:${MainBranch}"; Run "git push $MainBranch (must be a fast-forward)"

# ---- 5. Render ----------------------------------------------------------------------------------
if ($backendChanged) {
    Step 'Render: deploying the API'
    if ($Settings.RENDER_DEPLOY_HOOK_URL) {
        try { Invoke-RestMethod -Method Post -Uri $Settings.RENDER_DEPLOY_HOOK_URL -ErrorAction Stop | Out-Null }
        catch { Fail "Render deploy hook failed: $($_.Exception.Message)" }
        Write-Host 'Deploy triggered. It takes a few minutes; watch it in the Render dashboard.'
    } else {
        Write-Host "No RENDER_DEPLOY_HOOK_URL in .env.deploy - relying on Render's auto-deploy of '$MainBranch'." -ForegroundColor Yellow
    }
}

# ---- 6. Vercel ----------------------------------------------------------------------------------
if ($webChanged) {
    Step "Vercel: building the web app against $($Settings.API_BASE_URL)"
    Push-Location (Join-Path $Root 'mobile')
    try {
        flutter build web --release "--dart-define=API_BASE_URL=$($Settings.API_BASE_URL)"; Run 'flutter build web'
        Set-Location 'build/web'
        if ($Settings.VERCEL_TOKEN) {
            # Deploy as the Zuno Vercel account, whoever the CLI happens to be signed in as.
            $vercelArgs = @('--token', $Settings.VERCEL_TOKEN)
            if ($Settings.VERCEL_SCOPE) { $vercelArgs += @('--scope', $Settings.VERCEL_SCOPE) }
            $project = if ($Settings.VERCEL_PROJECT) { $Settings.VERCEL_PROJECT } else { 'zuno' }
            vercel link --yes --project $project @vercelArgs; Run 'vercel link'
            vercel deploy --prod --yes @vercelArgs; Run 'vercel deploy'
        } else {
            vercel deploy --prod --yes; Run 'vercel deploy'
        }
    } finally {
        Pop-Location
    }
}

Step "Done. $MainBranch is at $((git rev-parse --short HEAD))."
