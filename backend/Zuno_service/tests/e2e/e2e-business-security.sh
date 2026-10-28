#!/usr/bin/env bash
# Business module: security end to end, from sign-up to the end of the order lifecycle.
#
# WHAT THIS IS FOR
# The repository already has 16 integration tests covering JWT forgery and role separation, but
# they need Docker (Testcontainers) and Docker is not available on this machine — so they have
# never run here. This script covers the same ground against the REAL running API, and adds the
# one area nothing covered: cross-tenant access inside the business module.
#
# CROSS-TENANT is the gap worth closing. Role separation only proves a worker cannot reach a
# business route. It says nothing about whether business B can reach business A's orders, services,
# posts, crew and pay runs — which is the breach that actually matters in a marketplace, because
# every attacker already has a legitimate business account.
#
# Business rules are NOT under test here except to prove they still work. Nothing in this script
# asks for a rule to change.
#
# Sections
#   A  sign-up and password rules
#   B  the token itself
#   C  roles cannot reach each other's routes
#   D  CROSS-TENANT: business B against business A           <- the gap
#   E  the owner's own lifecycle still works (no rule changed)
#   F  input validation
API=${API:-http://localhost:5056/api/v1}
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
PASS=0; FAIL=0; SKIP=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-80; }

ok()   { PASS=$((PASS+1)); printf '  PASS  %-52s %s\n' "$1" "$2"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %-52s %s\n' "$1" "$2"; }
skip() { SKIP=$((SKIP+1)); printf '  SKIP  %-52s %s\n' "$1" "$2"; }
eq()   { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' want '$3'"; fi; }
head_() { printf '\n== %s ==\n' "$1"; }

cool() { printf '      (waiting out the rate-limit window)\n'; sleep 63; }

# Status code only — the right assertion for anything the pipeline refuses with no body.
code()  { local m="$1" p="$2" t="$3" b="${4:-{\}}"
  if [ -z "$t" ]; then
    curl -s -o /dev/null -w '%{http_code}' -X "$m" "$API$p" -H 'Content-Type: application/json' -d "$b"
  else
    curl -s -o /dev/null -w '%{http_code}' -X "$m" "$API$p" -H "Authorization: Bearer $t" -H 'Content-Type: application/json' -d "$b"
  fi; }
body()  { local m="$1" p="$2" t="$3" b="${4:-{\}}"
  curl -s -X "$m" "$API$p" -H "Authorization: Bearer $t" -H 'Content-Type: application/json' -d "$b"; }

# A refusal is either a 401/403 with no body, or a 200-shaped envelope saying success:false.
# Asserting on only one of those reports the other as an allow, which is backwards for security.
refused() {
  local label="$1" m="$2" p="$3" t="$4" b="${5:-{\}}"
  local out http
  out=$(curl -s -w '\n%{http_code}' -X "$m" "$API$p" -H "Authorization: Bearer $t" -H 'Content-Type: application/json' -d "$b")
  http=$(echo "$out" | tail -1)
  if [ "$http" = "401" ] || [ "$http" = "403" ] || [ "$http" = "404" ]; then ok "$label" "$http"; return; fi
  if echo "$out" | grep -q '"success":false'; then ok "$label" "refused: $(echo "$out" | msg)"; return; fi
  bad "$label" "ALLOWED ($http) — cross-tenant access got through"
}

reg_once() { curl -s -X POST $API/auth/register -H 'Content-Type: application/json' \
  -d "{\"firstName\":\"$1\",\"lastName\":\"T\",\"email\":\"$2\",\"password\":\"${4:-E2e@12345}\",\"phoneNumber\":\"$3\",\"role\":\"${5:-Worker}\"}"; }
free_phone() { local c; for _ in $(seq 1 50); do c="9$(shuf -i 100000000-999999999 -n 1)"; [ -z "$(sql "select 1 from users where phone_number='$c'")" ] && { echo "$c"; return; }; done; }
reg() { local b; b=$(reg_once "$@"); if ! echo "$b" | grep -q '"accessToken"'; then sleep 63; b=$(reg_once "$@"); fi; echo "$b"; }

echo "================================================================"
echo " ZUNO — BUSINESS MODULE SECURITY, END TO END"
echo " $(date '+%Y-%m-%d %H:%M')   against $API"
echo "================================================================"

head_ "A. SIGN-UP AND PASSWORD RULES"
PA=$(free_phone)
eq "A weak password is refused (no upper/digit/special)" \
   "$(code POST /auth/register '' "{\"firstName\":\"X\",\"lastName\":\"Y\",\"email\":\"w1_$S@zuno.local\",\"password\":\"password\",\"phoneNumber\":\"$PA\",\"role\":\"Worker\"}")" "400"
eq "A short password is refused" \
   "$(code POST /auth/register '' "{\"firstName\":\"X\",\"lastName\":\"Y\",\"email\":\"w2_$S@zuno.local\",\"password\":\"Aa1@\",\"phoneNumber\":\"$PA\",\"role\":\"Worker\"}")" "400"
eq "A malformed email is refused" \
   "$(code POST /auth/register '' "{\"firstName\":\"X\",\"lastName\":\"Y\",\"email\":\"not-an-email\",\"password\":\"E2e@12345\",\"phoneNumber\":\"$PA\",\"role\":\"Worker\"}")" "400"
eq "A non-Indian mobile is refused" \
   "$(code POST /auth/register '' "{\"firstName\":\"X\",\"lastName\":\"Y\",\"email\":\"w3_$S@zuno.local\",\"password\":\"E2e@12345\",\"phoneNumber\":\"12345\",\"role\":\"Worker\"}")" "400"
eq "SuperAdmin cannot be self-registered" \
   "$(code POST /auth/register '' "{\"firstName\":\"X\",\"lastName\":\"Y\",\"email\":\"w4_$S@zuno.local\",\"password\":\"E2e@12345\",\"phoneNumber\":\"$PA\",\"role\":\"SuperAdmin\"}")" "400"

cool

# Its own window: this is the sixth auth call, and the limiter allows five a minute — run with the
# others it measures the rate limiter rather than the rule.
eq "An existing email is refused" \
   "$(code POST /auth/register '' "{\"firstName\":\"X\",\"lastName\":\"Y\",\"email\":\"owner@zuno.local\",\"password\":\"E2e@12345\",\"phoneNumber\":\"$PA\",\"role\":\"Worker\"}")" "400"

head_ "SETTING UP TWO BUSINESSES, A CUSTOMER AND A WORKER"
AT=$(reg BossA "sec_a$S@zuno.local" "$(free_phone)" E2e@12345 BusinessOwner | j accessToken)
BT=$(reg BossB "sec_b$S@zuno.local" "$(free_phone)" E2e@12345 BusinessOwner | j accessToken)
CT=$(reg Cust  "sec_c$S@zuno.local" "$(free_phone)" E2e@12345 Customer     | j accessToken)
WT=$(reg Work  "sec_w$S@zuno.local" "$(free_phone)" E2e@12345 Worker       | j accessToken)
eq "Four accounts registered" "$([ -n "$AT" ] && [ -n "$BT" ] && [ -n "$CT" ] && [ -n "$WT" ] && echo yes)" "yes"
[ -n "$AT" ] && [ -n "$BT" ] && [ -n "$CT" ] && [ -n "$WT" ] || { echo "ABORTED: setup failed"; exit 1; }

BIZ_A=$(sql "select b.id from business_owner_profiles b join users u on u.id=b.user_id where u.email='sec_a$S@zuno.local'")
BIZ_B=$(sql "select b.id from business_owner_profiles b join users u on u.id=b.user_id where u.email='sec_b$S@zuno.local'")
sql "update business_owner_profiles set verification_status=1, verified_at=now() where id in ('$BIZ_A','$BIZ_B')" >/dev/null
DIST=$(sql "select id from districts limit 1")
WP=$(sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='sec_w$S@zuno.local'")

# Business A's world: a service, a variant, an order, a crew member, a hiring post.
SVC_A=$(body POST /business/services "$AT" "{\"serviceCategoryId\":\"a1111111-0000-0000-0000-000000000003\",\"name\":\"A Catering\",\"priceType\":\"Fixed\",\"price\":5000,\"requiredWorkerCount\":1,\"estimatedDurationMinutes\":120,\"districtIds\":[\"$DIST\"]}" | j id)
VAR_A=$(body POST /business/services/$SVC_A/variants "$AT" "{\"name\":\"A Deluxe\",\"priceType\":\"Fixed\",\"price\":9000}" | j id)
SOON=$(date -u -d '+3 days 10:00' +%Y-%m-%dT%H:%M:%SZ)
BK_A=$(body POST /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC_A\",\"scheduledDate\":\"$SOON\",\"addressLine1\":\"1 Road\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"latitude\":10.5276,\"longitude\":76.2144,\"country\":\"India\"}" | j id)
body POST /business/bookings/$BK_A/confirm "$AT" >/dev/null
body POST /business/workers/invite "$AT" "{\"workerIdentifier\":\"sec_w$S@zuno.local\"}" >/dev/null
INV=$(curl -s $API/worker/invitations -H "Authorization: Bearer $WT" | j id)
body POST /worker/invitations/$INV/respond "$WT" '{"accept":true}' >/dev/null
body POST /business/bookings/$BK_A/assign-worker "$AT" "{\"workerProfileId\":\"$WP\"}" >/dev/null
body POST /worker/jobs/$BK_A/respond "$WT" '{"accept":true}' >/dev/null
POST_A=$(body POST /business/hiring-posts "$AT" "{\"title\":\"A crew\",\"eventDate\":\"$SOON\",\"durationMinutes\":120,\"workersNeeded\":2,\"salaryAmount\":900,\"salaryUnit\":\"PerEvent\",\"location\":\"Thrissur\"}" | j id)
BW_A=$(sql "select id from business_workers where business_owner_profile_id='$BIZ_A' and is_deleted=false limit 1")
eq "Business A has a service, order, crew and post" \
   "$([ -n "$SVC_A" ] && [ -n "$BK_A" ] && [ -n "$POST_A" ] && [ -n "$BW_A" ] && echo yes)" "yes"

head_ "B. THE TOKEN ITSELF"
eq "No token"                 "$(code GET /business/bookings '')" "401"
eq "Rubbish in the header"    "$(curl -s -o /dev/null -w '%{http_code}' $API/business/bookings -H 'Authorization: Bearer not-a-token')" "401"
# Flip the last character of the signature: same header and payload, broken signature.
TAMPERED="${AT%?}$([ "${AT: -1}" = "A" ] && echo B || echo A)"
eq "A token with its signature altered" "$(curl -s -o /dev/null -w '%{http_code}' $API/business/bookings -H "Authorization: Bearer $TAMPERED")" "401"
# alg:none with a business-owner role claim, unsigned.
NONE_TOK="$(printf '{"alg":"none","typ":"JWT"}' | base64 -w0 | tr '+/' '-_' | tr -d '=').$(printf '{"sub":"00000000-0000-0000-0000-000000000001","http://schemas.microsoft.com/ws/2008/06/identity/claims/role":"BusinessOwner","exp":9999999999}' | base64 -w0 | tr '+/' '-_' | tr -d '=')."
eq "An unsigned alg:none token"  "$(curl -s -o /dev/null -w '%{http_code}' $API/business/bookings -H "Authorization: Bearer $NONE_TOK")" "401"
eq "Public catalogue still open"  "$(curl -s -o /dev/null -w '%{http_code}' $API/states)" "200"

head_ "C. ROLES CANNOT REACH EACH OTHER'S ROUTES"
eq "Customer -> business bookings" "$(code GET /business/bookings "$CT")" "403"
eq "Worker   -> business bookings" "$(code GET /business/bookings "$WT")" "403"
eq "Business -> worker jobs"       "$(code GET /worker/jobs "$AT")" "403"
eq "Business -> customer bookings" "$(code GET /customer/bookings "$AT")" "403"
eq "Business -> admin catalogue"   "$(code GET /admin/catalog/categories "$AT")" "403"
eq "Worker   -> admin businesses"  "$(code GET /admin/businesses "$WT")" "403"

cool

head_ "D. CROSS-TENANT — BUSINESS B AGAINST BUSINESS A"
echo "   (every one of these must be refused; B is a legitimate, verified business)"
refused "B reads A's order"                 GET  "/business/bookings/$BK_A" "$BT"
refused "B confirms A's order"              POST "/business/bookings/$BK_A/confirm" "$BT"
refused "B proposes terms on A's order"     POST "/business/bookings/$BK_A/terms" "$BT" '{"workerCount":1,"price":100}'
refused "B starts A's order"                POST "/business/bookings/$BK_A/start" "$BT"
refused "B completes A's order"             POST "/business/bookings/$BK_A/complete" "$BT"
refused "B cancels A's order"               POST "/business/bookings/$BK_A/cancel" "$BT" '{"reason":"x"}'
refused "B assigns a worker to A's order"   POST "/business/bookings/$BK_A/assign-worker" "$BT" "{\"workerProfileId\":\"$WP\"}"
refused "B sets a role on A's crew"         PUT  "/business/bookings/$BK_A/crew/$WP/role" "$BT" '{"role":"Lead"}'
refused "B changes A's crew size"           POST "/business/bookings/$BK_A/crew-size" "$BT" '{"requiredWorkerCount":9}'

refused "B edits A's service"               PUT    "/business/services/$SVC_A" "$BT" "{\"name\":\"stolen\",\"priceType\":\"Fixed\",\"price\":1,\"requiredWorkerCount\":1,\"estimatedDurationMinutes\":60,\"districtIds\":[\"$DIST\"]}"
refused "B deletes A's service"             DELETE "/business/services/$SVC_A" "$BT"
refused "B rewrites A's service questions"  PUT    "/business/services/$SVC_A/questions" "$BT" '{"questions":[]}'
refused "B adds a variant to A's service"   POST   "/business/services/$SVC_A/variants" "$BT" '{"name":"x","priceType":"Fixed","price":1}'
refused "B edits A's variant"               PUT    "/business/services/$SVC_A/variants/$VAR_A" "$BT" '{"name":"x","priceType":"Fixed","price":1}'
refused "B deletes A's variant"             DELETE "/business/services/$SVC_A/variants/$VAR_A" "$BT"

refused "B edits A's hiring post"           PUT    "/business/hiring-posts/$POST_A" "$BT" "{\"title\":\"stolen\",\"eventDate\":\"$SOON\",\"durationMinutes\":60,\"workersNeeded\":1,\"salaryAmount\":1,\"salaryUnit\":\"PerEvent\"}"
refused "B deletes A's hiring post"         DELETE "/business/hiring-posts/$POST_A" "$BT"
refused "B invites onto A's post"           POST   "/business/hiring-posts/$POST_A/invite" "$BT" "{\"workerIdentifier\":\"sec_w$S@zuno.local\"}"
refused "B starts A's post"                 POST   "/business/hiring-posts/$POST_A/start" "$BT"
refused "B completes A's post"              POST   "/business/hiring-posts/$POST_A/complete" "$BT"
refused "B opens a pay run on A's post"     POST   "/business/hiring-posts/$POST_A/payouts" "$BT" '{}'

refused "B removes A's team member"         DELETE "/business/workers/$BW_A" "$BT"
refused "B reads A's worker's diary"        GET    "/business/workers/$WP/busy-dates" "$BT"

cool

head_ "D2. CROSS-ROLE ON SOMEONE ELSE'S BOOKING"
CTRL=$(code GET "/worker/jobs/$BK_A" "$WT")
eq "Control: the assigned worker CAN read their job" "$CTRL" "200"
refused "Customer reads A's order by the business route" GET "/business/bookings/$BK_A" "$CT"

head_ "E. THE OWNER'S OWN LIFECYCLE STILL WORKS (no rule changed)"
eq "A reads its own order"   "$(code GET "/business/bookings/$BK_A" "$AT")" "200"
sql "update bookings set scheduled_date=now() - interval '1 hour' where id='$BK_A'" >/dev/null
R=$(body POST /business/bookings/$BK_A/start "$AT")
if echo "$R" | grep -q '"success":true'; then ok "A starts its own work" ""; else bad "A starts its own work" "$(echo "$R" | msg)"; fi
R=$(body PUT /business/bookings/$BK_A/crew/$WP/role "$AT" '{"role":"Lead"}')
if echo "$R" | grep -q '"success":true'; then ok "A names a Lead on its own order" ""; else bad "A names a Lead on its own order" "$(echo "$R" | msg)"; fi
R=$(body POST /business/bookings/$BK_A/complete "$AT")
if echo "$R" | grep -q '"success":true'; then ok "A completes its own work" ""; else bad "A completes its own work" "$(echo "$R" | msg)"; fi
eq "...and the order is Completed" "$(sql "select booking_status from bookings where id='$BK_A'")" "4"

head_ "F. INPUT VALIDATION"
eq "A negative price is refused" \
   "$(code POST /business/services "$AT" "{\"serviceCategoryId\":\"a1111111-0000-0000-0000-000000000003\",\"name\":\"bad\",\"priceType\":\"Fixed\",\"price\":-5,\"requiredWorkerCount\":1,\"estimatedDurationMinutes\":60,\"districtIds\":[\"$DIST\"]}")" "400"
eq "A blank service name is refused" \
   "$(code POST /business/services "$AT" "{\"serviceCategoryId\":\"a1111111-0000-0000-0000-000000000003\",\"name\":\"\",\"priceType\":\"Fixed\",\"price\":10,\"requiredWorkerCount\":1,\"estimatedDurationMinutes\":60,\"districtIds\":[\"$DIST\"]}")" "400"
eq "An unknown price type is refused" \
   "$(code POST /business/services "$AT" "{\"serviceCategoryId\":\"a1111111-0000-0000-0000-000000000003\",\"name\":\"bad\",\"priceType\":\"Nonsense\",\"price\":10,\"requiredWorkerCount\":1,\"estimatedDurationMinutes\":60,\"districtIds\":[\"$DIST\"]}")" "400"
eq "A made-up category is refused" \
   "$(code POST /business/services "$AT" "{\"serviceCategoryId\":\"99999999-9999-9999-9999-999999999999\",\"name\":\"bad\",\"priceType\":\"Fixed\",\"price\":10,\"requiredWorkerCount\":1,\"estimatedDurationMinutes\":60,\"districtIds\":[\"$DIST\"]}")" "400"
LONG=$(printf 'x%.0s' $(seq 1 600))
eq "An over-long name is refused" \
   "$(code POST /business/services "$AT" "{\"serviceCategoryId\":\"a1111111-0000-0000-0000-000000000003\",\"name\":\"$LONG\",\"priceType\":\"Fixed\",\"price\":10,\"requiredWorkerCount\":1,\"estimatedDurationMinutes\":60,\"districtIds\":[\"$DIST\"]}")" "400"
# Parameterised queries mean this is stored as a name, never executed. Proving it stays data.
INJ="Robert'); DROP TABLE bookings;--"
SVC_INJ=$(body POST /business/services "$AT" "{\"serviceCategoryId\":\"a1111111-0000-0000-0000-000000000003\",\"name\":\"$INJ\",\"priceType\":\"Fixed\",\"price\":10,\"requiredWorkerCount\":1,\"estimatedDurationMinutes\":60,\"districtIds\":[\"$DIST\"]}" | j id)
eq "SQL in a name is stored as text, not run" "$(sql "select count(*) from information_schema.tables where table_name='bookings'")" "1"
[ -n "$SVC_INJ" ] && ok "...and the service was created with that literal name" "" || bad "...service with odd name" "rejected"

echo
echo "================================================================"
printf ' PASS %s   FAIL %s   SKIP %s\n' "$PASS" "$FAIL" "$SKIP"
echo "================================================================"
[ "$FAIL" -eq 0 ]
