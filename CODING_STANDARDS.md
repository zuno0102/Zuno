# Zuno — Application Coding Standards

These rules apply to every change in this repository: the .NET backend (`backend/`), the Flutter
app (`mobile/`), the launcher (`launcher/`) and the PostgreSQL database. A change that breaks a
**MUST** rule is not merged.

**Stack this document is written for**

| Layer | Technology |
|---|---|
| API | ASP.NET Core, versioned controllers (`Asp.Versioning`), JWT Bearer auth |
| Application | MediatR (CQRS), FluentValidation, Mapster |
| Data | EF Core + Npgsql (PostgreSQL on Neon), snake_case naming, Redis cache |
| Resilience / logs | Polly, Serilog |
| Mobile | Flutter, Riverpod (code-gen), go_router, Dio, flutter_secure_storage, freezed |

---

## Contents

1. [No hard-coded values — make it table/config driven](#1-no-hard-coded-values--make-it-tableconfig-driven)
2. [Remove unwanted code](#2-remove-unwanted-code)
3. [Code optimisation](#3-code-optimisation)
4. [High-performance coding](#4-high-performance-coding)
5. [Security, JWT and token handling](#5-security-jwt-and-token-handling)
6. [Everything dynamic, nothing tightly coupled](#6-everything-dynamic-nothing-tightly-coupled)
7. [Separate the code into clear parts](#7-separate-the-code-into-clear-parts)
8. [No trap code](#8-no-trap-code)
9. [Cyber-security: protect the application from attack](#9-cyber-security-protect-the-application-from-attack)
10. [Clean and build everything](#10-clean-and-build-everything)
11. [Built for 10,000,000 users](#11-built-for-10000000-users)
12. [Database standards and security](#12-database-standards-and-security)
13. [Unit testing — every scenario covered](#13-unit-testing--every-scenario-covered)
14. [Code review — high-performance focus](#14-code-review--high-performance-focus)
15. [Pull-request checklist](#15-pull-request-checklist)

---

## 1. No hard-coded values — make it table/config driven

**Rule:** a value that could ever change — a price, a limit, a status label, a radius, a timeout,
a URL, a feature on/off — does not live as a literal in code.

Where each kind of value belongs:

| Kind of value | Where it lives | Example |
|---|---|---|
| Business data that admins change (service types, fees, cities, service areas, cancellation windows) | **Database table**, cached in Redis | `service_categories`, `platform_settings` |
| Environment-specific settings (connection strings, base URLs, CORS origins) | `appsettings.{Environment}.json` + environment variables | `ConnectionStrings:Default` |
| Secrets (JWT key, DB password, Razorpay keys) | Environment variables / secret store **only** | `Jwt__SigningKey` |
| Fixed technical constants (route names, header names) | One constants class per area | `ApiConstants`, `ClaimNames` |
| Feature flags | `feature_flags` table or config, read through one service | `IFeatureFlagService` |
| User-facing text (mobile) | Localisation files / server-provided labels | `app_en.arb` |

**Backend**

```csharp
// ❌ Not allowed
if (booking.DistanceKm > 25) throw new ValidationException("Too far");

// ✅ Read from settings (table-driven, cached)
var maxKm = await _settings.GetAsync<decimal>(SettingKeys.MaxServiceDistanceKm, ct);
if (booking.DistanceKm > maxKm) ...
```

- Bind configuration with the **Options pattern** (`IOptions<T>` / `IOptionsMonitor<T>`), validated
  at startup with `ValidateDataAnnotations().ValidateOnStart()`.
- Enums are fine for states the **code** branches on (e.g. `BookingStatus`). Display names,
  colours and ordering for those states come from data, not `switch` statements in the UI.

**Mobile**

- The API base URL comes from `--dart-define` / flavour config, never from a literal in a widget.
- Dropdown options, categories, prices and limits are fetched from the API, not built into the app
  — so they can change without a store release.
- Colours, spacing and text styles come from the theme (`Theme.of(context)`), not inline values.

---

## 2. Remove unwanted code

- **No dead code:** unused classes, methods, parameters, imports, providers, routes, assets and
  NuGet / pub packages are deleted, not commented out. Git keeps the history.
- **No commented-out code blocks** in a commit.
- **No debug leftovers:** `print`, `debugPrint`, `Console.WriteLine`, temporary endpoints,
  test buttons and `TODO: remove` are removed before merge. Use Serilog / a logger.
- **No duplicate logic:** if two places do the same thing, extract one shared function.
- Run the analysers (section 10) — they must report **zero** unused-code warnings.
- When a feature is removed, remove all of it: endpoint, handler, validator, DTO, migration-safe DB
  cleanup, mobile screen, provider, route and tests.

---

## 3. Code optimisation

- **Small, single-purpose functions.** One method does one thing; aim for < 40 lines.
- **Fail fast** with guard clauses instead of deep nesting.
- **Choose the right data structure:** `Dictionary`/`HashSet` (or Dart `Map`/`Set`) for lookups,
  not repeated `List.Contains` / `firstWhere` inside loops.
- **No work inside loops that can be done once outside** (DB calls, regex construction, config reads).
- **Avoid needless allocations:** no `ToList()` just to call `Count`/`Any`; use `StringBuilder` for
  string building in loops; reuse `HttpClient` through `IHttpClientFactory`.
- **Mobile rebuilds:** use `const` widgets, `ref.watch(provider.select(...))` to listen to only the
  field you need, `ListView.builder` for lists, and keep `build()` free of heavy work.
- **Images:** compress before upload (`flutter_image_compress`), use `cached_network_image` and
  request sized thumbnails from the server.
- Measure before optimising complex code; keep the simple version unless profiling shows a problem.

---

## 4. High-performance coding

**Backend**

- **Async all the way.** Every I/O call is `async` and receives the `CancellationToken`.
  Never `.Result`, `.Wait()` or `Task.Run` around I/O.
- **Read queries** use `AsNoTracking()` and **project** to DTOs with `Select(...)` /
  `ProjectToType<T>()` — never load whole entities to return a few fields.
- **No N+1 queries.** Load related data in one query (`Include` or projection); check generated
  SQL in development logs.
- **Pagination is mandatory** for every list endpoint (keyset/cursor paging preferred for large or
  feed-style lists; a hard maximum page size from config).
- **Cache** read-heavy, rarely-changing data (settings, categories, service areas) in Redis with
  an expiry and explicit invalidation on update.
- **Response compression** and **output caching** for public, cacheable GETs.
- **External calls** (maps/Nominatim, payments, push) go through typed `HttpClient`s with Polly
  timeout, retry with back-off and circuit breaker. Never block a request on a slow third party
  when it can be queued.
- **Background work** (notifications, emails, cleanups) runs in hosted/background services or a
  queue, not inside the HTTP request.

**Mobile**

- Never block the UI thread; heavy parsing/compression runs off the main isolate (`compute`).
- Debounce search inputs and map movements before calling the API.
- Cancel in-flight Dio requests when a screen is disposed (`CancelToken`).
- Poll only when the screen is visible, and prefer push/real-time updates over polling.

---

## 5. Security, JWT and token handling

**Authentication**

- Every endpoint requires authentication by default (global `AuthorizeFilter` / fallback policy).
  Public endpoints must opt out explicitly with `[AllowAnonymous]` and be reviewed.
- **JWT access token:** short-lived (e.g. 15 minutes), signed with a strong key
  (HS256 ≥ 256-bit secret, or RS256), with `iss`, `aud`, `exp`, `nbf`, `sub`, `jti` and role claims.
  Validation checks issuer, audience, lifetime and signing key with a small `ClockSkew`.
- **Refresh token:** long-lived, random (cryptographically secure), stored **hashed** in the
  database, **rotated on every use**, bound to the device/session, and revocable.
  Reuse of an old refresh token revokes the whole session family.
- Logout and password change revoke refresh tokens server-side.
- Signing keys and secrets come from environment variables only and are never logged or committed.

**Authorisation**

- Role- and policy-based authorisation (`[Authorize(Policy = ...)]`) — customer, worker, business,
  admin.
- **Resource ownership is checked on every request:** a user may only read or change records that
  belong to them (booking, chat, notification, payment). The user id comes from the token
  (`ICurrentUserService`), **never** from the request body or query string.

**Mobile token storage**

- Tokens are stored only in `flutter_secure_storage` — never `shared_preferences`, logs or files.
- A Dio interceptor attaches the access token, refreshes it once on `401` (single in-flight refresh,
  queued retries) and signs the user out if refresh fails.
- On sign-out, clear tokens and all cached user data; a new sign-in never sees the previous user's
  state.

**Passwords**

- Hashed with BCrypt (work factor from config); never stored, logged or returned in any form.
- OTP / reset codes are single-use, short-lived, rate-limited and stored hashed.

---

## 6. Everything dynamic, nothing tightly coupled

- **Depend on interfaces, not implementations.** Application code uses `IPlaceSearchService`,
  `IPaymentGateway`, `INotificationSender`, `IDateTimeProvider`, etc.; Infrastructure provides the
  implementations; the API wires them up with dependency injection.
- **No `new` of services** inside business logic, no static service locators, no static mutable state.
- **Swap providers through config**, not code changes (e.g. switching map or SMS provider).
- **Communicate through MediatR** commands/queries and domain events instead of handlers calling
  each other directly.
- **Mobile:** screens depend on Riverpod providers; providers depend on repository interfaces;
  only data sources know about Dio. A widget never calls the API directly.
- **Configurable rules:** status flows, limits, fees and permissions are data/config driven so new
  cases need configuration, not new `if` branches.
- Every external dependency must be mockable in unit tests — if it isn't, the code is too coupled.

---

## 7. Separate the code into clear parts

**Backend — Clean Architecture (dependencies point inwards only)**

```
Zuno.Domain          Entities, value objects, enums, domain rules. No framework references.
Zuno.Application     Use cases: Modules/<Feature>/Commands|Queries/<UseCase>/
                     (Command/Query, Handler, Validator, DTOs), interfaces in Common/Interfaces.
Zuno.Infrastructure  EF Core DbContext, configurations, migrations, Redis, HTTP clients,
                     external services (maps, payments, push).
Zuno.Api             Thin controllers, middleware, auth, versioning, DI composition.
tests/               Mirrors the src structure, one test class per use case.
```

- Controllers only: receive the request → send a MediatR command/query → return the result.
  No business logic and no `DbContext` in controllers.
- One use case per folder; one public type per file; file name = type name.

**Mobile — feature-first**

```
lib/core/                 Shared: constants, network (Dio, interceptors), theme, routing, utils.
lib/features/<feature>/
    data/                 datasources (API calls), models (DTOs), repository implementations
    domain/               entities, repository interfaces (when the feature needs them)
    presentation/         providers, screens, widgets
```

- A feature does not import another feature's `data/` layer; share through `core/` or a provider.
- Generated files (`*.g.dart`, `*.freezed.dart`) are regenerated, never edited by hand.

---

## 8. No trap code

"Trap code" is code that works today but fails silently or surprises the next developer.
None of the following is allowed:

- **Swallowed exceptions:** empty `catch {}` / `catch (_) {}`. Catch only what you can handle,
  log it, and return a clear result. Unhandled errors go to the global exception middleware.
- **Hidden side effects:** a "Get" method that also writes, or a getter that calls the network.
- **Magic behaviour:** special-casing a particular user id, phone number or email; secret
  backdoor accounts; debug-only bypasses that can reach production.
- **Infinite or unbounded loops/retries:** every loop, retry and poll has a limit and a back-off.
- **Fire-and-forget tasks** without error handling (`_ = DoSomethingAsync();`).
- **Null traps:** nullable reference types are enabled in .NET and sound null safety in Dart;
  do not silence them with `!` / `null!` without a proven reason.
- **Time-bombs:** hard-coded dates, expiries or "temporary" switches with no owner.
- **Race conditions:** concurrent updates to the same record use optimistic concurrency
  (row version / `xmin`) or a DB constraint, not "check then write".
- **Money as floating point:** use `decimal` (C#) and integer minor units or decimal strings across
  the API.

---

## 9. Cyber-security: protect the application from attack

Follow the **OWASP Top 10** and **OWASP Mobile Top 10**. Minimum controls:

| Threat | Required control |
|---|---|
| SQL injection | EF Core LINQ or parameterised SQL only. Never build SQL with string concatenation/interpolation. `FromSqlRaw` with user input is forbidden — use `FromSqlInterpolated`. |
| Broken access control / IDOR | Ownership check on every resource (section 5); IDs in URLs are never trusted on their own. |
| Invalid / malicious input | Every command and query has a FluentValidation validator: types, lengths, ranges, formats, allow-lists. Reject unknown fields. |
| XSS / injection in output | Encode output; never render user HTML; sanitise text shown in web/admin views. |
| Brute force / abuse / DoS | ASP.NET rate limiting per IP and per user on login, OTP, search, booking and upload endpoints; request size limits; timeouts. |
| File upload attacks | Allow-list of types checked by content (magic bytes), max size, random server-side file names, store outside the web root / in object storage, never execute. |
| Sensitive data exposure | HTTPS only (HSTS); no secrets, tokens, passwords, OTPs or full card/phone data in logs or error responses; return generic error messages with a correlation id. |
| Security misconfiguration | Strict CORS allow-list from config; security headers (`X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, CSP for web); Swagger disabled in production. |
| Mass assignment | Bind requests to dedicated command/DTO types, never directly to entities. |
| Payment tampering | Amounts are calculated on the server; Razorpay signatures/webhooks verified server-side; idempotency keys on payment and booking creation. |
| Vulnerable dependencies | `dotnet list package --vulnerable` and `flutter pub outdated` checked before release; no unmaintained packages. |
| Mobile reverse engineering | Release builds obfuscated (`--obfuscate --split-debug-info`); no secrets in the app bundle; certificate pinning for the API where possible. |
| Audit | Security-relevant actions (login, role change, payment, admin edits) written to an audit log. |

Run `/security-review` (or an equivalent review) on every change that touches auth, payments,
uploads or data access.

---

## 10. Clean and build everything

Before every push the following **must pass with zero errors and zero warnings**:

**Backend**

```powershell
cd backend
dotnet clean
dotnet restore
dotnet build -c Release -warnaserror
dotnet test -c Release --no-build
dotnet format --verify-no-changes
```

- `Nullable` enabled and `TreatWarningsAsErrors` set in `Directory.Build.props`.

**Mobile**

```powershell
cd mobile
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

- Release build checked with `flutter build apk --release --obfuscate --split-debug-info=build/symbols`.

**Repository**

- No build output, `bin/`, `obj/`, `build/`, `.env`, keys or local databases committed.
- Branch flow: work on `Zuno_Dev` → merge to `main`; deploy with `deploy.ps1`
  (see [DEPLOYMENT.md](DEPLOYMENT.md)).

---

## 11. Built for 10,000,000 users

Code must be written so the system can scale **horizontally** — add more servers, not bigger ones.

- **Stateless API.** No user state in server memory or local disk; sessions live in tokens,
  Redis or the database. Any instance can serve any request.
- **Database is protected:** every query is indexed and paginated; connection pooling is
  configured; read-heavy endpoints use cache; consider read replicas for reporting.
- **Cache first** for hot, shared data, with sensible TTLs and cache-stampede protection.
- **Asynchronous processing:** notifications, emails, image processing, reports and
  analytics go through background jobs / queues.
- **Idempotent writes:** booking, payment and notification endpoints accept an idempotency key so
  retries never create duplicates.
- **Limits everywhere:** page size, upload size, request rate, query time-outs.
- **Real-time over polling** for chat and live status where possible; when polling is required,
  use back-off and stop when the app is in the background.
- **Mobile is a good citizen:** caches responses, retries with back-off and jitter
  (`dio_smart_retry`), never loops on failure.
- **Observability:** structured Serilog logs with correlation ids, health checks
  (`/health`), metrics on latency, error rate and DB time. Alerts on error spikes.
- **Load test** critical flows (sign-in, search, create booking, payment) before major releases
  and after any change to them.

---

## 12. Database standards and security

**Design**

- PostgreSQL naming: `snake_case`, plural table names, `id` primary key (UUID or `bigint`
  identity), `created_at` / `updated_at` in UTC (`timestamptz`), `created_by` / `updated_by`
  where auditing is needed.
- Use constraints to protect data: `NOT NULL`, `FOREIGN KEY`, `UNIQUE`, `CHECK` — the database
  must reject bad data even if the code has a bug.
- **Index** every foreign key and every column used in `WHERE`, `JOIN` or `ORDER BY` on large
  tables; use composite and partial indexes where they fit the query.
- Lookup values (statuses, categories, settings) live in reference tables, not repeated strings.
- **Soft delete** (`is_deleted`, `deleted_at`) for business records that must be auditable, with
  a global query filter.
- Optimistic concurrency on records that can be edited concurrently.

**Changes**

- Every schema change is an **EF Core migration**, reviewed, committed and applied by the deploy
  process. No manual changes in production.
- Migrations must be backward compatible with the running version (add → backfill → switch →
  remove in a later release).
- Large data changes run in batches, never one huge transaction.

**Security**

- The application connects with a **least-privilege** database user (no superuser, no DDL
  rights at runtime); migrations use a separate user.
- Connections use **TLS** (`SSL Mode=Require`); connection strings come from environment
  variables only.
- Personally identifiable information (phone, address, ID documents) is minimised, never
  logged, and encrypted at rest where required; passwords and tokens are stored only as hashes.
- Database is not reachable from the public internet except through the provider's secured
  endpoint; IP allow-list where supported.
- **Backups:** automated daily backups plus point-in-time recovery (Neon branching/PITR); restore
  is tested regularly.
- Slow-query logging is enabled; any query over the agreed threshold is fixed or indexed.

---

## 13. Unit testing — every scenario covered

**Rule:** no feature, fix or refactor is merged without tests that cover **all** of its scenarios —
the happy path, every failure path, every boundary and every security rule. A bug fix starts with a
test that fails because of the bug.

**Test tools in this repo**

| Project | Purpose | Tools |
|---|---|---|
| `backend/tests/Zuno.Application.UnitTests` | Handlers, validators, domain rules | xUnit, Moq, FluentAssertions |
| `backend/tests/Zuno.Infrastructure.UnitTests` | Repositories, external service clients, caching | xUnit, Moq, FluentAssertions |
| `backend/tests/Zuno.Api.IntegrationTests` | Full HTTP pipeline: auth, routing, validation, real PostgreSQL | `WebApplicationFactory`, Testcontainers.PostgreSql |
| `backend/tests/e2e` | End-to-end user journeys | — |
| `mobile/test/` | Providers, repositories, data sources, widgets | `flutter_test`, Riverpod `ProviderContainer` with overrides |

### 13.1 The scenario matrix

For every command, query, endpoint, provider and screen, write a test for **each row that applies**.
A PR that leaves a row out must say why.

| # | Scenario | Example (create booking) |
|---|---|---|
| 1 | **Happy path** — valid input, expected result and side effects | Booking saved, status `Pending`, notification queued |
| 2 | **Validation — each rule on its own** | Missing service, past date, empty address, note too long |
| 3 | **Boundaries** — min, max, just inside, just outside, zero, empty | Distance = max radius (allowed), max + 0.01 (refused) |
| 4 | **Null / missing / malformed data** | Null coordinates, unknown enum value, bad GUID |
| 5 | **Not found** | Service or business does not exist → `404` |
| 6 | **Authentication** | No token, expired token, bad signature → `401` |
| 7 | **Authorisation / ownership** | Customer A tries to read customer B's booking → `403`/`404` |
| 8 | **Business-rule failures** | Business does not cover the area; slot already taken |
| 9 | **State transitions** — every allowed and every forbidden move | `Completed → Cancelled` is refused |
| 10 | **Duplicates and idempotency** | Same idempotency key twice → one booking only |
| 11 | **Concurrency** | Two workers accept the same job → one wins, one gets a conflict |
| 12 | **External dependency failure** | Maps / payment / push times out or returns `500` → handled, no crash, no partial write |
| 13 | **Configuration-driven behaviour** | Changing the setting value changes the result (proves no hard-coding) |
| 14 | **Security inputs** | SQL/script injection strings, oversized payloads, forged ids are rejected safely |
| 15 | **Pagination and empty results** | Empty list, single page, last page, page size above max is capped |
| 16 | **Time and time-zone** | Uses `IDateTimeProvider`; around midnight / DST / UTC conversion |
| 17 | **Mobile UI states** | Loading, data, empty, error, retry, signed-out, offline |

### 13.2 How tests are written

- **Name:** `Method_Scenario_ExpectedResult`, e.g.
  `Handle_WhenBusinessDoesNotCoverArea_ReturnsValidationError`.
- **Structure:** Arrange → Act → Assert, one behaviour per test. Use `[Theory]` with
  `[InlineData]`/`[MemberData]` for boundary and validation sets instead of copy-pasted tests.
- **Assert the outcome _and_ the side effects:** returned value, saved data, events raised,
  messages sent — and that nothing happened when it should not (`Times.Never`).
- **Isolated and repeatable:** no shared mutable state, no real network, no dependence on test
  order, the clock (`IDateTimeProvider` / fake clock) or random values without a fixed seed.
- **Fast:** unit tests run in milliseconds; anything needing a real database or HTTP pipeline is an
  integration test.
- **Test builders / factories** create valid objects with defaults so each test only states what
  matters to it. No hard-coded magic values scattered through tests.
- **Mobile:** override repositories and data sources with fakes through
  `ProviderContainer(overrides: [...])`; widget tests use `pumpWidget` inside a `ProviderScope`
  and check every UI state from 13.1 row 17.
- **Never** delete, skip (`Skip =`, `skip:`) or weaken a failing test to make the build pass —
  fix the code or, if the requirement changed, change the test and say so in the PR.

### 13.3 Coverage gates

| Area | Minimum line coverage | Minimum branch coverage |
|---|---|---|
| `Zuno.Domain`, `Zuno.Application` (handlers, validators, rules) | 90% | 85% |
| `Zuno.Infrastructure` | 75% | 70% |
| Mobile providers, repositories, data sources | 85% | 80% |
| Mobile widgets / screens | 60% | — |

Coverage is a floor, not the goal — a test that runs code without asserting the result does not
count. Measure with:

```powershell
dotnet test backend -c Release --collect:"XPlat Code Coverage"
flutter test --coverage
```

### 13.4 Performance and load tests

- Critical queries have an integration test that asserts the **number of SQL queries** (no N+1) and
  that results are paginated.
- Before a major release, sign-in, search, create booking, chat and payment are load-tested at the
  target concurrency; p95 latency and error rate must stay within the agreed budget (section 14.3).

---

## 14. Code review — high-performance focus

**Rule:** every change is reviewed by at least one other developer before it reaches `main`.
Changes to auth, payments, uploads, database schema or shared infrastructure need **two** reviewers.
The author runs a self-review with this list first.

### 14.1 Review order

1. **Correctness** — does it do what the ticket says in every scenario from 13.1?
2. **Security** — sections 5 and 9.
3. **Performance and scale** — 14.2 below.
4. **Design** — layering, coupling, no hard-coding (sections 1, 6, 7).
5. **Tests** — every scenario covered, tests would fail if the code were wrong (section 13).
6. **Readability** — names, size, no dead code (sections 2, 3).

### 14.2 Performance review checklist

**Database**

- [ ] Reads use `AsNoTracking()` and project only the needed columns into a DTO.
- [ ] No query inside a loop (N+1); related data loaded in one round trip.
- [ ] Every new `WHERE`, `JOIN` and `ORDER BY` column on a large table has an index.
- [ ] List endpoints are paginated with a capped page size; no unbounded `ToListAsync()`.
- [ ] `Count`/`Any` done in SQL, not after loading rows into memory.
- [ ] Writes are batched; transactions are short and never wrap external HTTP calls.
- [ ] Generated SQL checked for the new query (development logs / `ToQueryString()`).

**API / backend**

- [ ] All I/O is `async` with `CancellationToken` passed through; no `.Result` / `.Wait()`.
- [ ] Hot, rarely changing data is cached with expiry and invalidation.
- [ ] Slow or non-essential work (notifications, emails, images) is moved to background processing.
- [ ] External calls have timeout, retry with back-off and circuit breaker; no unbounded retries.
- [ ] No large objects held in memory per request; streams used for files.
- [ ] No per-request allocation of `HttpClient`, regex, serializer options or other heavy objects.
- [ ] Logging is structured and not excessive in hot paths; nothing sensitive is logged.
- [ ] Responses return only what the client needs (no over-fetching, no nested entity graphs).

**Mobile**

- [ ] `const` widgets used; `ref.watch(...select(...))` limits rebuilds to the needed field.
- [ ] Long lists use `ListView.builder` / slivers; images are cached and sized.
- [ ] No heavy work in `build()`; JSON parsing / compression of large data off the main isolate.
- [ ] Search and map events are debounced; requests cancelled when the screen closes.
- [ ] Polling stops in the background and uses back-off; no request storms on retry.
- [ ] Controllers, streams, timers and subscriptions are disposed.

**Scale (10M users)**

- [ ] Code is stateless — works the same on any API instance.
- [ ] Writes that may be retried are idempotent.
- [ ] Rate and size limits exist for the new endpoint.
- [ ] The change does not add a single shared bottleneck (global lock, single-row counter, synchronous fan-out).

### 14.3 Performance budgets

A change that breaks a budget is not approved until it is fixed or the budget change is agreed.

| Metric | Budget |
|---|---|
| API p95 latency — simple reads | ≤ 200 ms |
| API p95 latency — writes / searches | ≤ 500 ms |
| Database queries per request | ≤ 5 for normal endpoints |
| Single SQL query time | ≤ 100 ms (slow-query alert above this) |
| API error rate (5xx) | < 0.1% |
| Mobile cold start to first screen | ≤ 2 s on a mid-range device |
| Mobile frame rendering | 60 fps, no frames over 16 ms in normal scrolling |

### 14.4 Review rules

- Small PRs (aim for under ~400 changed lines) are reviewed faster and better; split big ones.
- Comments are about the code, not the person; each comment says **what** and **why**, and marks
  whether it is **blocking** or a **suggestion**.
- The reviewer checks out and builds the branch for non-trivial changes; CI must be green
  (section 10) before review is approved.
- Automated help is used, not relied on alone: `flutter analyze`, .NET analysers, `/code-review`
  and `/security-review` in Claude Code.
- All blocking comments are resolved before merge; follow-up work gets its own ticket, not a TODO.

---

## 15. Pull-request checklist

Copy into every PR description and tick each item.

```
- [ ] No hard-coded values; new settings are in a table or config (section 1)
- [ ] No dead, duplicate, commented-out or debug code (section 2)
- [ ] Queries projected, no N+1, paginated, AsNoTracking for reads (sections 3–4)
- [ ] Endpoints authorised; ownership checked; user id taken from the token (section 5)
- [ ] Depends on interfaces; registered through DI; testable (section 6)
- [ ] Files in the correct layer/feature folder (section 7)
- [ ] No swallowed exceptions, unbounded loops or hidden side effects (section 8)
- [ ] Input validated; rate limits and size limits in place; no secrets in logs (section 9)
- [ ] Clean build, analysers, formatter and all tests pass with zero warnings (section 10)
- [ ] Stateless, cached where useful, idempotent writes, background work queued (section 11)
- [ ] Migration added and reviewed; indexes and constraints present (section 12)
- [ ] Unit/integration tests cover every applicable scenario; coverage gates met (section 13)
- [ ] Performance review checklist passed; budgets respected (section 14)
- [ ] Reviewed and approved (two reviewers for auth, payments, uploads, schema) (section 14)
```
