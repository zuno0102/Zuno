# Deploying Zuno on free tiers

Written for: whoever deploys or redeploys this, including future-you.

Three tiers, three providers:

| Tier | Provider | What runs there |
|---|---|---|
| Data | **Neon** | PostgreSQL 16 |
| API | **Render** | the .NET 9 API, as a Docker service |
| Web front end | **Vercel** | the Flutter web build, as static files |
| Android app | **GitHub Releases** | the APK, built against the live API, one release per version |

The APK talks to whatever `--dart-define=API_BASE_URL=...` it was built with; `deploy.ps1` always
builds it against the live API, the same as the website.

---

## How Zuno ships — read this before every deploy

**The only repository is https://github.com/zuno0102/Zuno.** Not `Riva0904/Zuno`, not
`zuno0102/ZunoProject`. **Every part of Zuno uses the Zuno accounts** — GitHub `zuno0102`, Vercel
team `Zuno_team` — never a personal account (`Riva0904`, `bsundaram-6826`). `git remote -v` must
show exactly:

```
origin  https://github.com/zuno0102/Zuno.git
```

| Thing | Value |
|---|---|
| Work branch | `Zuno_Dev` — every change is committed here first |
| Release branch | `main` — always a fast-forward of `Zuno_Dev`, never committed to directly |
| API (Render) | service `zuno-api` → https://zuno-api-qon8.onrender.com, deploys branch **`main`** |
| Web (Vercel) | team `Zuno_team` (`zuno-team1`), project `zuno` → **https://zuno-infinite-service.vercel.app** — the only website (linked from `mobile/build/web` by `deploy.ps1` with `VERCEL_TOKEN`). The old bsundaram site and the zuno-ten-henna address were deleted on 2026-10-21. |
| Android APK (GitHub) | release `v<version>` on zuno0102/Zuno, marked **Latest**. Always-newest download link: **https://github.com/zuno0102/Zuno/releases/latest/download/zuno.apk** |
| Commit author | `zuno0102 <342959199+zuno0102@users.noreply.github.com>` (`git config user.name/user.email` in this repo) |
| Database (Neon) | PostgreSQL; schema changes go out with `dotnet ef database update` |

### Deploy with one command

From the repository root, in PowerShell:

```powershell
.\deploy.ps1 -Message "What changed and why"
```

It does, in this order, and only the parts that are needed:

1. commits uncommitted changes to `Zuno_Dev`;
2. compares against `origin/main` (what is live) to see what changed;
3. **Neon** — if `Persistence/Migrations/` changed and `NEON_CONNECTION_STRING` is set, runs
   `dotnet ef database update` against Neon *before* the new API goes out (optional: the API also
   migrates itself on start-up);
4. pushes `Zuno_Dev`, then fast-forwards `main` to it;
5. **Render** — if `backend/` or `render.yaml` changed, calls the deploy hook;
6. **Vercel** — if the Flutter app changed, rebuilds the web app against the live API and deploys it;
7. **APK** — if the Flutter app changed (`mobile/lib`, `assets`, `android`, `pubspec`), builds the
   release APK against the live API and publishes it on GitHub as release `v<version>` (the version
   in `mobile/pubspec.yaml`), marked **Latest**, with the commit message as its notes. Two files go
   up: `zuno-v<version>.apk` and `zuno.apk` — the second is what the always-newest link serves.

So **every change you commit and push live updates the website and the APK together**: dev branch,
main branch, live website, live API and the downloadable APK all carry the same code.

With nothing to commit it just deploys whatever `main` is missing; `-Force` redeploys Render,
Vercel and the APK regardless. `-SkipApk` leaves the APK for another time.

#### Versions and the APK

- **Bump `version:` in `mobile/pubspec.yaml` for every app release** (e.g. `1.2.4+8` → `1.2.5+9`):
  the part before `+` names the release (`v1.2.5`), the number after `+` must go up or Android
  refuses to install it over the old one.
- Shipping again **without** a bump replaces the APK on that same release instead of making a new
  one — fine for a quick fix, but phones that already installed that version will not see it as
  an update.
- Installing: open the link on the phone, download `zuno.apk`, open it, allow "Install unknown
  apps" if asked. An existing Zuno is updated in place and stays signed in.

### One-time setup for the script

1. Copy `deploy.env.example` to `.env.deploy` (gitignored) and fill in:
   - `RENDER_DEPLOY_HOOK_URL` — Render → `zuno-api` → **Settings → Deploy Hook**;
   - `NEON_CONNECTION_STRING` — Neon dashboard → **Connect**, in the Npgsql form shown below;
   - `VERCEL_TOKEN` — signed in to Vercel as the Zuno account: **Account Settings → Tokens**,
     scope **Zuno_team**; `VERCEL_SCOPE` = the team slug from its dashboard URL;
     `VERCEL_PROJECT` = `zuno`. With the token the script deploys as Zuno no matter which account
     `vercel login` is signed in to.
2. Render → `zuno-api` → **Settings**: repository `zuno0102/Zuno`, branch **`main`**, auto-deploy on.
3. Git signed in to GitHub as `zuno0102` (Windows Credential Manager → `git:https://github.com`),
   and commits authored as `zuno0102`:
   ```powershell
   git config user.name "zuno0102"
   git config user.email "342959199+zuno0102@users.noreply.github.com"
   ```
4. GitHub CLI signed in as `zuno0102` (`gh auth login`, check with `gh auth status`) — the APK
   step publishes releases with it and stops before pushing anything if it is signed in as anyone
   else.
5. Android release signing: `mobile/android/key.properties` (gitignored) pointing at the upload
   keystore. Keep that keystore safe — an APK signed with a different key cannot update the
   installed app.

### Render environment variables that must be set

`ConnectionStrings__ZunoDatabase`, `Cors__AllowedOrigins__0` (= `https://zuno-infinite-service.vercel.app`,
exactly, no trailing slash or newline),
`Razorpay__KeyId`, `Razorpay__KeySecret`, `AdminSeed__Email`, `AdminSeed__Password`, and `Verification__AutoVerifyBusinesses` (`false`: a Super Admin approves
each business; `true`: approved automatically — either way only after it passes validation).

---

## Read this first: what the free tiers cannot do

Three limits change how the app behaves. None are bugs, and none can be fixed by configuration.

**1. Uploaded pictures do not survive.** Render's free plan gives a container with no disk attached.
Every logo, service picture, package picture, video and hiring-post image is written to the
container's own filesystem, so all of it disappears on every deploy *and* every time the service
wakes from sleep. The database keeps pointing at URLs whose files are gone, so those images turn
into broken pictures rather than vanishing cleanly.

This is the one part of the app that genuinely does not work on free hosting. Fixing it means
putting the files somewhere else — Cloudflare R2 and Supabase Storage both have usable free tiers,
and `IFileStorageService` is a single interface with one implementation, so it is a contained
change. Until then, treat uploaded images as temporary.

**2. The API sleeps.** After about 15 minutes with no requests, Render stops the free service. The
next request starts it again, which takes roughly 30–60 seconds, and the app's HTTP timeouts are 15
seconds — so the first person to arrive after an idle period sees timeouts, not a slow load. Tapping
again a minute later works. Neon's free compute also suspends after 5 minutes idle, adding about a
second on top.

**3. Razorpay keys are required to boot.** The API validates them at start-up and refuses to run
without them, on purpose: a payment system that starts up half-configured is worse than one that
does not start. Test keys are fine. Simulated collection is refused outside Development by the app
itself, so wages on the deployed site need a real payment to settle.

---

## One-time setup

### Log in (you have to do this part)

Each of these opens a browser. Run them in your own terminal, signed in to the browser as the
**Zuno** account first — the approval page uses whoever the browser is signed in as. For Vercel the
`VERCEL_TOKEN` in `.env.deploy` replaces `vercel login`.

```bash
neonctl auth
render login
```

### 1. Neon — the database

```bash
neonctl projects create --name zuno --region-id aws-ap-southeast-1
neonctl connection-string --project-id <id> --database-name neondb
```

Neon prints a libpq URI. Npgsql needs its own format, so convert it:

```
Host=<endpoint>.neon.tech;Database=neondb;Username=<user>;Password=<password>;SSL Mode=Require;Trust Server Certificate=true
```

Keep `SSL Mode=Require` — Neon refuses unencrypted connections.

Then create the schema. Run this from `backend/`, pointing at Neon:

```bash
ConnectionStrings__ZunoDatabase="<the connection string above>" \
  dotnet ef database update --project Zuno_service/src/Zuno.Infrastructure --startup-project Zuno_service/src/Zuno.Api
```

The migrations seed the catalogue: 8 service categories, 36 states, 765 districts, and the four
roles. They do **not** seed an admin — see below, because without one the site cannot function.

### 2. Render — the API

The blueprint is `render.yaml` at the repository root. Push it, then in Render choose
**New → Blueprint** and point it at the repository. Render reads the file and asks for the values
marked `sync: false`:

| Prompt | What to give it |
|---|---|
| `ConnectionStrings__ZunoDatabase` | the Npgsql string from step 1 |
| `Cors__AllowedOrigins__0` | your Vercel URL, e.g. `https://zuno.vercel.app`, no trailing slash |
| `Razorpay__KeyId` / `Razorpay__KeySecret` | from the Razorpay dashboard |

`JwtSettings__SigningKey` is generated by Render. Nobody needs to see it.

The health check is `/api/v1/service-categories` — a public endpoint that touches the database, so a
passing health check means the API really can reach Neon.

### 3. Vercel — the web front end

The build happens here, not on Vercel: Vercel's build image has no Flutter, and installing it per
build is slow and brittle. The API address is compiled into the bundle, so it must be rebuilt
whenever that address changes.

```bash
cd mobile
flutter build web --release --dart-define=API_BASE_URL=https://zuno-api-qon8.onrender.com
cd build/web
vercel link --yes --project zuno --scope <Zuno_team slug> --token <VERCEL_TOKEN>
vercel deploy --prod --yes --scope <Zuno_team slug> --token <VERCEL_TOKEN>
```

`deploy.ps1` runs exactly these two commands when `VERCEL_TOKEN` is set (the link only the first
time). **The Vercel project must not be connected to GitHub** (project → Settings → Git →
Disconnect): `vercel link` connects it automatically, and then every push to `main` makes Vercel
build from the repository, which has no Flutter — the result is an empty site that answers 404.

`mobile/web/vercel.json` is copied into `build/web` by the build. It sends every path to
`index.html` and leaves the entry points uncached so a new deploy is actually picked up.

Then go back and set `Cors__AllowedOrigins__0` in Render to the URL Vercel gives you. Until you do,
every request from the site is refused by the browser, and the app will look broken while the API
is perfectly healthy.

### 4. Seed an admin — do not skip this

A fresh database has no admin account, and registration deliberately refuses the `SuperAdmin` role,
so there is no way to create one through the app. Without an admin **no business can ever be
approved, and an unapproved business is invisible to customers** — the marketplace has nothing in
it, and nothing in the UI explains why.

**The easy way:** set `AdminSeed__Email` and `AdminSeed__Password` in Render. On start-up the API
creates that Super Admin if none exists yet (and does nothing once one does). Sign in with it on the
normal login screen — the app opens the admin panel for that role.

The password must meet the same rules as every account (8+ characters, upper and lower case, a digit
and a symbol); a weaker one is refused and logged, and no admin is created. Once you have signed in,
**delete both variables from Render** — the admin exists, and a password left in the environment is
one more place it can leak from.

The manual way, if you cannot use the seeder — register an ordinary account, then promote it:

```bash
curl -X POST https://zuno-api-qon8.onrender.com/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@yourdomain.com","password":"<a real password>","firstName":"Zuno","lastName":"Admin","role":"Customer"}'
```

Then against Neon:

```sql
-- Promote that account, and give it the admin profile the role expects.
update users
set role_id = '44444444-4444-4444-4444-444444444444',  -- SuperAdmin, seeded by migration
    email_confirmed = true,
    is_active = true
where email = 'admin@yourdomain.com';

delete from customer_profiles
where user_id = (select id from users where email = 'admin@yourdomain.com');

insert into admin_profiles (id, user_id, created_date, is_deleted, status)
select gen_random_uuid(), id, now(), false, 1
from users where email = 'admin@yourdomain.com';
```

Done this way the password is hashed by the application itself (BCrypt, work factor 12), so there is
no hand-written hash to get wrong.

---

## Changing order stage names, colours and filters — no release needed

The status words on orders ("Active", "Awaiting payment"…) and the filter chips on the business
Orders tabs come from the `order_stages` table, not from the apps (CODING_STANDARDS §1). Edit the
rows in Neon and every app picks them up the next time it starts:

```sql
-- Rename a stage
update order_stages set display_name = 'Payment due' where stage = 4;
-- Move it in the filter row (lowest first)
update order_stages set sort_order = 2 where stage = 4;
-- Colour family: success | progress | waiting | danger
update order_stages set tone = 'danger' where stage = 4;
-- Show or hide it as a filter on the Bookings / Status management tab
update order_stages set show_on_bookings = true, show_on_work = false where stage = 4;
```

`stage` is the fixed code the server decides with: 1 Active · 2 Confirmed · 3 In progress ·
4 Awaiting payment · 5 Completed · 6 Cancelled. Never change or renumber it; change everything else.

---

## Redeploying

Use `.\deploy.ps1` (see the top of this file). What it automates:

- **API** — pushed to `main`, then the Render deploy hook (or Render's auto-deploy of `main`).
- **Web** — rebuilt and redeployed, because the API address is baked in.
- **Schema change** — the API applies pending migrations itself on start-up
  (`Database:MigrateOnStartup`, on by default), using the connection string Render already has,
  and logs which ones it applied. A failed migration stops the new instance from starting, so
  Render keeps serving the previous deploy. When `NEON_CONNECTION_STRING` is set, the script also
  applies them before pushing, which is harmless: the API then finds nothing pending.

## If something is wrong

| Symptom | Cause |
|---|---|
| Site loads, every request fails, browser console says CORS | `Cors__AllowedOrigins__0` does not exactly match the site's origin |
| First visit times out, second works | the free service was asleep — expected, see above |
| API will not start, logs mention `RazorpaySettings` or `JwtSettings` | a required setting is missing; the app refuses to boot half-configured |
| Images were there yesterday and are broken today | the container was replaced — expected on the free plan, see above |
| Everyone is rate-limited at once | `UseForwardedHeaders` is not running, so every request looks like it comes from Render's proxy |
