#!/usr/bin/env bash
# Paying the crew you put on the job yourself.
#
# Until now only workers hired through a post carried a wage. A worker the business added by hand
# had no salary, no payment status, and appeared in neither the wage rollup nor the pay run — so
# an order staffed entirely by hand owed nobody, and counted toward the business's record as fully
# settled the moment the work finished, while that crew had been paid nothing.
#
# What this pins:
#   * a hand-added worker can carry a wage, and half a wage is refused
#   * the order's outstanding total counts them
#   * a worker with NO wage is not a payee and never holds the order open
#   * an unpaid hand-added worker DOES stop the order counting toward the profile
#   * both ways onto a job are added together, not one or the other
API=http://localhost:5056/api/v1
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-90; }
errs(){ tr '[' '\n' | grep -oE '"[^"]*(per|amount|blank)[^"]*"' | head -1 | tr -d '"' | cut -c1-80; }

ok()  { PASS=$((PASS+1)); printf 'PASS  %-56s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-56s %s\n' "$1" "$2"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }
want_ok()   { if echo "$2" | grep -q '"success":true'; then ok "$1" "$3"; else bad "$1" "$(echo "$2" | msg)"; fi; }
want_fail() { if echo "$2" | grep -q '"success":true'; then bad "$1" "it was accepted"; else ok "$1" "$(echo "$2" | errs)"; fi; }

reg() {
  local body
  body=$(curl -s -X POST $API/auth/register -H 'Content-Type: application/json' \
    -d "{\"firstName\":\"$1\",\"lastName\":\"T\",\"email\":\"$2\",\"password\":\"E2e@12345\",\"phoneNumber\":\"9$((RANDOM%900000000+100000000))\",\"role\":\"$3\"}")
  if ! echo "$body" | grep -q '"accessToken"'; then
    sleep 62
    body=$(curl -s -X POST $API/auth/register -H 'Content-Type: application/json' \
      -d "{\"firstName\":\"$1\",\"lastName\":\"T\",\"email\":\"$2\",\"password\":\"E2e@12345\",\"phoneNumber\":\"9$((RANDOM%900000000+100000000))\",\"role\":\"$3\"}")
  fi
  echo "$body"
}
post_() { curl -s -X POST "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "${3:-\{\}}"; }
get_()  { curl -s "$API$1" -H "Authorization: Bearer $2"; }
counted() { sql "select completed_job_count from business_owner_profiles where id='$BIZ'"; }
owed()    { get_ "/business/bookings/$BID" "$BT" | grep -o '"wageOutstandingAmount":[0-9.]*' | head -1 | cut -d: -f2; }
payees()  { get_ "/business/bookings/$BID" "$BT" | grep -o '"wagePayeeCount":[0-9]*' | head -1 | cut -d: -f2; }

join_worker() { # email -> worker profile id, joined to the business
  post_ /business/workers/invite "$BT" "{\"workerIdentifier\":\"$1\"}" >/dev/null
  local tok=$2
  local inv
  inv=$(get_ /worker/invitations "$tok" | tr '{' '\n' | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
  post_ "/worker/invitations/$inv/respond" "$tok" '{"accept":true}' >/dev/null
  sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='$1'"
}

echo "================ SETUP ================"
BT=$(reg Boss "dw_b$S@zuno.local" BusinessOwner | j accessToken)
CT=$(reg Asha "dw_c$S@zuno.local" Customer | j accessToken)
W1=$(reg Ravi "dw_w1$S@zuno.local" Worker | j accessToken)
W2=$(reg Anita "dw_w2$S@zuno.local" Worker | j accessToken)
if [ -z "$BT" ] || [ -z "$CT" ] || [ -z "$W2" ]; then echo "registration failed (rate limit?)"; exit 1; fi
sql "update business_owner_profiles set verification_status=1, verified_at=now() where user_id=(select id from users where email='dw_b$S@zuno.local')" >/dev/null
BIZ=$(sql "select b.id from business_owner_profiles b join users u on u.id=b.user_id where u.email='dw_b$S@zuno.local'")
CAT=$(sql "select id from service_categories where slug='cleaning' and is_deleted=false")
DIST=$(sql "select id from districts where is_deleted=false limit 1")
eq "Starting count is zero" "$(counted)" "0"

WP1=$(join_worker "dw_w1$S@zuno.local" "$W1")
WP2=$(join_worker "dw_w2$S@zuno.local" "$W2")
ok "Two workers joined the business" "Ravi, Anita"

SVC=$(post_ /business/services "$BT" "{\"serviceCategoryId\":\"$CAT\",\"name\":\"Deep clean $S\",\"priceType\":\"Fixed\",\"price\":5000,\"requiredWorkerCount\":2,\"districtIds\":[\"$DIST\"]}" | j id)
SOON=$(date -u -d '+3 days 10:00' +%Y-%m-%dT%H:%M:%SZ)
BID=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$SOON\",\"addressLine1\":\"1 Road\",\"city\":\"Kochi\",\"state\":\"Kerala\",\"postalCode\":\"682001\"}" | j id)
want_ok "Order confirmed" "$(post_ "/business/bookings/$BID/confirm" "$BT")" ""

echo
echo "==== 1. HALF A WAGE IS REFUSED ===="
# An amount with no unit cannot be read: 800 an hour and 800 for the event differ by a factor of
# eight on a long day. Refused rather than defaulted, because guessing reprices someone's work.
want_fail "An amount with no unit" \
  "$(post_ "/business/bookings/$BID/assign-worker" "$BT" "{\"workerProfileId\":\"$WP1\",\"salaryAmount\":800}")"
want_fail "A unit with no amount" \
  "$(post_ "/business/bookings/$BID/assign-worker" "$BT" "{\"workerProfileId\":\"$WP1\",\"salaryUnit\":\"PerEvent\"}")"
want_fail "A wage of zero"        \
  "$(post_ "/business/bookings/$BID/assign-worker" "$BT" "{\"workerProfileId\":\"$WP1\",\"salaryAmount\":0,\"salaryUnit\":\"PerEvent\"}")"
eq "Nobody was assigned by any of those" "$(sql "select count(*) from booking_worker_assignments where booking_id='$BID'")" "0"

echo
echo "==== 2. ONE PAID THROUGH ZUNO, ONE NOT ===="
want_ok "Ravi added at 800 per event" \
  "$(post_ "/business/bookings/$BID/assign-worker" "$BT" "{\"workerProfileId\":\"$WP1\",\"role\":\"Lead\",\"salaryAmount\":800,\"salaryUnit\":\"PerEvent\"}")" ""
want_ok "Anita added with no wage (paid outside Zuno)" \
  "$(post_ "/business/bookings/$BID/assign-worker" "$BT" "{\"workerProfileId\":\"$WP2\"}")" ""
eq "Both are on the job"        "$(sql "select count(*) from booking_worker_assignments where booking_id='$BID' and is_deleted=false")" "2"
eq "Ravi's wage was stored"     "$(sql "select agreed_salary_amount from booking_worker_assignments where booking_id='$BID' and worker_profile_id='$WP1'")" "800.00"
eq "...with its unit (1=PerEvent)" "$(sql "select agreed_salary_unit from booking_worker_assignments where booking_id='$BID' and worker_profile_id='$WP1'")" "1"
eq "Anita has no wage"          "$(sql "select coalesce(agreed_salary_amount::text,'null') from booking_worker_assignments where booking_id='$BID' and worker_profile_id='$WP2'")" "null"

echo
echo "==== 3. THE ORDER KNOWS WHAT IT OWES ===="
# One payee, not two: a worker with no wage is not owed anything through Zuno, and counting them
# as a zero-rupee payee would leave the order reading "0 of 2 paid" for ever.
eq "One payee, not two"   "$(payees)" "1"
eq "800 outstanding"      "$(owed)"   "800.00"

echo
echo "==== 4. AN UNPAID HAND-ADDED WORKER HOLDS THE COUNT BACK ===="
sql "update bookings set scheduled_date=now() - interval '1 hour' where id='$BID'" >/dev/null
# The worker's respond endpoint is keyed on the BOOKING, not the assignment row — a worker has at
# most one assignment per job, so the booking already names it.
post_ "/worker/jobs/$BID/respond" "$W1" '{"accept":true}' >/dev/null
want_ok "Work started"       "$(post_ "/business/bookings/$BID/start" "$BT")" ""
want_ok "Work marked done"   "$(post_ "/business/bookings/$BID/complete" "$BT")" ""
# The assertion this whole change exists for. Before it, this read 1.
eq "NOT counted while Ravi is unpaid" "$(counted)" "0"

echo
echo "==== 5. PAYING HIM LETS IT COUNT ===="
sql "update booking_worker_assignments set payment_status=3 where booking_id='$BID' and worker_profile_id='$WP1'" >/dev/null
# Recalculated on the next thing that touches the business's record.
post_ "/business/bookings/$BID/complete" "$BT" >/dev/null
eq "Ravi reads as paid" "$(sql "select payment_status from booking_worker_assignments where booking_id='$BID' and worker_profile_id='$WP1'")" "3"
# The API renders a zero decimal as 0, not 0.00.
# Compared as a number. The API renders zero as 0, 0.0 or 0.00 depending on the value's scale,
# and a string comparison picks a fight with the formatter rather than with the code.
zero() { case "$1" in 0|0.0|0.00|0.000) return 0;; *) return 1;; esac; }
if zero "$(owed)"; then ok "Nothing outstanding" "$(owed)"; else bad "Nothing outstanding" "got '$(owed)'"; fi

echo
echo "==== 6. A JOB WHERE NOBODY IS PAID THROUGH ZUNO ===="
BID2=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$SOON\",\"addressLine1\":\"1 Road\",\"city\":\"Kochi\",\"state\":\"Kerala\",\"postalCode\":\"682001\"}" | j id)
post_ "/business/bookings/$BID2/confirm" "$BT" >/dev/null
post_ "/business/bookings/$BID2/assign-worker" "$BT" "{\"workerProfileId\":\"$WP2\"}" >/dev/null
eq "No payees at all" \
   "$(get_ "/business/bookings/$BID2" "$BT" | grep -o '"wagePayeeCount":[0-9]*' | head -1 | cut -d: -f2)" "0"
eq "...and nothing owed" \
   "$(get_ "/business/bookings/$BID2" "$BT" | grep -o '"wageOutstandingAmount":[0-9.]*' | head -1 | cut -d: -f2)" "0"

echo
echo "================ $PASS passed, $FAIL failed ================"
[ "$FAIL" -eq 0 ]
