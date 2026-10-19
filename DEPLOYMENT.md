# Deploying Zuno on free tiers

Written for: whoever deploys or redeploys this, including future-you.

Three tiers, three providers:

| Tier | Provider | What runs there |
|---|---|---|
| Data | **Neon** | PostgreSQL 16 |
| API | **Render** | the .NET 9 API, as a Docker service |
| Web front end | **Vercel** | the Flutter web build, as static files |

The Android app is unaffected by all of this — it keeps talking to whatever
`--dart-define=API_BASE_URL=...` you build it with.

---

## How Zuno ships — read this before every deploy

**The only repository is https://github.com/zuno0102/Zuno.** Not `Riva0904/Zuno`, not
`zuno0102/ZunoProject`. `git remote -v` must show exactly:

```
origin  https://github.com/zuno0102/Zuno.git
```

| Thing | Value |
|---|---|
| Work branch | `Zuno_Dev` — every change is committed here first |
| Release branch | `main` — always a fast-forward of `Zuno_Dev`, never committed to directly |
| API (Render) | service `zuno-api` → https://zuno-api-qon8.onrender.com, deploys branch **`main`** |
| Web (Vercel) | project `web` (linked from `mobile/build/web`) → https://web-three-zeta-59.vercel.app |
| Database (Neon) | PostgreSQL; schema changes go out with `dotnet ef database update` |

### Deploy with one command

From the repository root, in PowerShell:

```powershell
.\deploy.ps1 -Message "What changed and why"
```

It does, in this order, and only the parts that are needed:

1. commits uncommitted changes to `Zuno_Dev`;
2. compares against `origin/main` (what is live) to see what changed;
3. **Neon** — if `Persistence/Migrations/` changed, runs `dotnet ef database update` against Neon
   *before* the new API goes out;
4. pushes `Zuno_Dev`, then fast-forwards `main` to it;
5. **Render** — if `backend/` or `render.yaml` changed, calls the deploy hook;
6. **Vercel** — if the Flutter app changed, rebuilds the web app against the live API and deploys it.

With nothing to commit it just deploys whatever `main` is missing; `-Force` redeploys Render and
Vercel regardless.

### One-time setup for the script

1. Copy `deploy.env.example` to `.env.deploy` (gitignored) and fill in:
   - `RENDER_DEPLOY_HOOK_URL` — Render → `zuno-api` → **Settings → Deploy Hook**;
   - `NEON_CONNECTION_STRING` — Neon dashboard → **Connect**, in the Npgsql form shown below.
2. Render → `zuno-api` → **Settings**: repository `zuno0102/Zuno`, branch **`main`**, auto-deploy on.
3. `vercel login` once (the CLI must be signed in to the account that owns the `web` project).
4. Git signed in to GitHub as `zuno0102` (Windows Credential Manager → `git:https://github.com`).

### Render environment variables that must be set

`ConnectionStrings__ZunoDatabase`, `Cors__AllowedOrigins__0` (= `https://web-three-zeta-59.vercel.app`),
`Razorpay__KeyId`, `Razorpay__KeySecret`, `AdminSeed__Email`, `AdminSeed__Password`, and — while
testing, until the admin verification screen exists — `Verification__AutoVerifyBusinesses=true`.

### Google Maps (optional, recommended)

Without Google the app uses free OpenStreetMap/Esri maps and OpenStreetMap search. In villages such as
Verkilambi OpenStreetMap has only the main roads, so customers cannot see their own lane. With Google
keys set, the pin picker, order cards and worker maps show Google's map (lanes, buildings, shops) and
the search finds local landmarks. Every part falls back to the free version when its key is missing.

One-time setup in the Google Cloud console (https://console.cloud.google.com), project "Zuno":

1. **Billing** → link a billing account (Google gives a monthly free allowance; set a budget alert).
2. **APIs & Services → Library** → enable: *Maps JavaScript API*, *Maps SDK for Android*,
   *Places API (New)*, *Geocoding API*.
3. **APIs & Services → Credentials → Create credentials → API key**, three times:

| Key | Application restriction | API restriction | Goes into |
|---|---|---|---|
| Browser | Websites: `https://web-three-zeta-59.vercel.app/*` | Maps JavaScript API | `.env.deploy` → `GOOGLE_MAPS_WEB_KEY` |
| Android | Android apps: package `com.zuno.zuno` + release SHA-1 | Maps SDK for Android | build flag `--dart-define=GOOGLE_MAPS_KEY=...` for the APK |
| Server | None (Render's IP changes) | Places API (New), Geocoding API | Render → `GoogleMaps__ApiKey` |

Then `.\deploy.ps1 -Force` rebuilds the web app with the browser key; Render picks up the server key
on its next deploy.

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

Each of these opens a browser. Run them in your own terminal:

```bash
vercel login
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
  dotnet ef database update --project src/Zuno.Infrastructure --startup-project src/Zuno.Api
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
vercel deploy --prod
```

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

## Redeploying

Use `.\deploy.ps1` (see the top of this file). What it automates:

- **API** — pushed to `main`, then the Render deploy hook (or Render's auto-deploy of `main`).
- **Web** — rebuilt and redeployed, because the API address is baked in.
- **Schema change** — `dotnet ef database update` against Neon *before* the API deploy that
  needs it. Nothing migrates on start-up, deliberately: a failed migration during a cold start
  would take the API down with no clear reason why.

## If something is wrong

| Symptom | Cause |
|---|---|
| Site loads, every request fails, browser console says CORS | `Cors__AllowedOrigins__0` does not exactly match the site's origin |
| First visit times out, second works | the free service was asleep — expected, see above |
| API will not start, logs mention `RazorpaySettings` or `JwtSettings` | a required setting is missing; the app refuses to boot half-configured |
| Images were there yesterday and are broken today | the container was replaced — expected on the free plan, see above |
| Everyone is rate-limited at once | `UseForwardedHeaders` is not running, so every request looks like it comes from Render's proxy |
