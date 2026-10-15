# End-to-end scenario scripts

Written for: anyone who needs to prove a change did not break the business rules.

These drive the running API over HTTP exactly as the apps do, and check the results in the
database. Between them they make **791 assertions across 21 scenarios**, covering ground the unit
and integration tests cannot: whole journeys, with real money, real crews and real refusals.

They complement the test projects beside this folder rather than replacing them.

| | What it proves |
|---|---|
| `Zuno.Application.UnitTests` | one handler's rules, in isolation, in milliseconds |
| `Zuno.Api.IntegrationTests` | the HTTP surface and token handling, against a throwaway Postgres |
| **these scripts** | a whole journey across many endpoints, where the interesting bugs live |

## Running them

They need three things: a running API, a Postgres they may write to, and `psql` on the PATH.

```bash
export PGPASSWORD=<your postgres password>     # required; the scripts refuse to run without it
export ZUNO_DB=zuno                            # optional, defaults to zuno
export API=http://localhost:5056/api/v1        # optional, most default to this
export PSQL=psql                               # optional, if psql is not on the PATH

bash e2e-business-full.sh
```

**They write to the database they are pointed at.** They create accounts, bookings and payments,
and some wipe data outright. Point them at a scratch database, never at anything you care about:

```bash
createdb zuno_scratch
ZUNO_DB=zuno_scratch bash e2e-business-full.sh
```

Every script exits non-zero if any assertion fails, so they work in CI as they stand.

## The ones worth knowing

| Script | Scenario |
|---|---|
| `e2e-business-full.sh` | sign-up to settled wages — 93 checks, the one to run if you only run one |
| `e2e-business-security.sh` | what one business can and cannot see of another |
| `e2e-booking-hire.sh` | the order lifecycle, the three hiring channels, and who may cancel when |
| `e2e-order-lifecycle.sh` | the five tracks of an order, including the date arriving on its own |
| `e2e-job-lead.sh` | per-job crew roles — only Lead can move the work, and only on that job |
| `e2e-payout-rules.sh` | a pay run funded once however many times it is confirmed |
| `e2e-pay-on-mobile.sh` | wages are not released without a payment Razorpay vouches for |
| `e2e-service-media.sh` | pictures and video, and that one business cannot overwrite another's |
| `e2e-admin-verify-business.sh` | the approval gate every business waits behind |
| `e2e-notifications.sh` | every notification, who gets it, and what it opens |

## Two that need the API started differently

- `e2e-pay-on-mobile.sh` must run with simulated collection **off** (the default), because it proves
  wages are refused when the payment cannot be verified.
- `e2e-payout-rules.sh`, `e2e-notifications-money.sh` and the money leg of `e2e-business-full.sh`
  need it **on**, because they test what happens after a payment succeeds:

  ```bash
  Razorpay__SimulateCollection=true dotnet run --project src/Zuno.Api
  ```

  Simulated collection reports wages as sent without moving money, so the application refuses it
  outside Development.

## If a lot of them fail at once

Check the rate limiter first. The scripts make many requests from one address, and the limits are
5/minute for auth and 100/minute overall. Raise them for a test run rather than removing them:

```bash
RateLimiting__Auth__PermitLimit=100000 RateLimiting__Global__PermitLimit=100000 \
  dotnet run --project src/Zuno.Api
```
