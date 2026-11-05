# Zuno deploy pipeline

How every change goes from your machine to live: **Zuno_Dev → main → live**. Use only
`https://github.com/zuno0102/Zuno`. The full background (accounts, secrets, first-time set-up) is in
[DEPLOYMENT.md](DEPLOYMENT.md).

## What runs where

| Part | Code | Live | Deploys when |
|---|---|---|---|
| Service API (.NET) | `backend/Zuno_service` | Render `zuno-api` → https://zuno-api-qon8.onrender.com | `main` changes (auto-deploy) |
| Rent API (.NET) | `backend/Zuno_rent` | Render `zuno-rent-api` → https://zuno-rent-api.onrender.com | `main` changes (auto-deploy) |
| Service DB (Postgres) | `Zuno_service/.../Persistence/Migrations` | Neon `misty-breeze-90136767`, db `neondb` | the Service API starts (MigrateOnStartup) |
| Rent DB (Postgres) | `Zuno_rent/.../Migrations` | Neon same project, db `zuno_rent` | the Rent API starts (MigrateOnStartup) |
| Website (Flutter web) | `mobile/` | Vercel team `zuno-team1`, project `zuno` → https://zuno-infinite-service.vercel.app | `deploy.ps1` builds and uploads it |
| Android APK | `mobile/` | GitHub release `v<version>` (Latest) → https://github.com/zuno0102/Zuno/releases/latest/download/zuno.apk | `deploy.ps1` builds and publishes it |

The website and the APK are built with both addresses:
`--dart-define=API_BASE_URL=https://zuno-api-qon8.onrender.com --dart-define=RENT_API_BASE_URL=https://zuno-rent-api.onrender.com`.

## Every release, in order

### 1. Before committing (on your machine)
- [ ] Bump `version:` in `mobile/pubspec.yaml` when the app changed (e.g. `1.10.0+35` → `1.10.1+36`).
- [ ] Backend tests pass:
  ```
  dotnet test backend/Zuno_service/tests/Zuno.Application.UnitTests
  dotnet test backend/Zuno_service/tests/Zuno.Infrastructure.UnitTests
  dotnet test backend/Zuno_rent/tests/Zuno.Rent.UnitTests
  ```
- [ ] App checks pass, from `mobile/`: `flutter analyze` and `flutter test`.
- [ ] A new migration is checked on a local database first: `dotnet ef database update`.
- [ ] Old apps still work: a server change must accept what the previous APK sends (new fields
      optional, no endpoint the old app calls removed).

### 2. Commit to Zuno_Dev
```
git checkout Zuno_Dev
git add -A
git commit            # title: "<version>: <short summary>", body: one line per change
git push origin Zuno_Dev
```

### 3. Main and live: one command
```
.\deploy.ps1
```
It does, in this order, and stops at the first error:
1. Checks the remote is zuno0102/Zuno and you are on `Zuno_Dev`.
2. Lists what changed since the last deploy (`origin/main`).
3. **DB**: applies Service migrations to Neon first, if `NEON_CONNECTION_STRING` is in
   `.env.deploy`. Otherwise the API applies them when it starts. Rent applies its own on start.
4. **main**: pushes `Zuno_Dev` and fast-forwards `main` to it (never a merge commit).
5. **.NET**: Render deploys both APIs from `main`.
6. **Website**: builds `mobile/` for the web and deploys it to Vercel.
7. **APK**: builds it and publishes GitHub release `v<version>` as Latest.

Options: `-SkipApk` (website and APIs only), `-Force` (redeploy without changes),
`-SkipMigrations`.

### 4. Check live (5 minutes after)
- [ ] https://zuno-api-qon8.onrender.com/health and https://zuno-rent-api.onrender.com/health say
      `Healthy`. On the free plan the first call can take about 50 seconds.
- [ ] Render dashboard: both services show **Deployed** on the new commit.
- [ ] https://zuno-infinite-service.vercel.app/version.json shows the new version.
- [ ] Neon: the newest migration is in `__EFMigrationsHistory` (`migration_id`) of each database.
- [ ] Log in on the website and the APK; open Service and Rent.
- [ ] Anything with money (UPI QR, online pay): try once on a real phone.

## When something goes wrong
| Problem | Fix |
|---|---|
| Render **Deploy failed**, "Exited with status 134" | Open the service's **Logs**. Usually a missing or wrong environment variable. Render keeps the previous deploy serving. |
| Website shows an old version | Hard refresh once. `vercel.json` makes app files reload, so this should be rare. |
| Website broken after a deploy | `vercel promote <previous deployment>` from the Vercel dashboard. |
| A migration failed | The new API does not start and Render keeps the old one. Fix the migration, commit, deploy again. |
| `deploy.ps1`: "origin/Zuno_Dev has commits you do not" | `git pull --rebase origin Zuno_Dev`, then run it again. |

## Secrets (never in git, never in chat)
- `.env.deploy` (gitignored): `VERCEL_TOKEN`, `VERCEL_SCOPE`, optional `NEON_CONNECTION_STRING`,
  `RENDER_DEPLOY_HOOK_URL`.
- Render environment, per service:
  - `zuno-api`: database, `JwtSettings__*`, Razorpay keys, CORS.
  - `zuno-rent-api`: `ConnectionStrings__RentDatabase`, the **same** `JwtSettings__SigningKey` as
    `zuno-api`, `ServiceApi__BaseUrl`, CORS, and optionally `Razorpay__KeyId` / `Razorpay__KeySecret`.
