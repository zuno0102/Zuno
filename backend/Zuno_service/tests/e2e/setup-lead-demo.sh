#!/usr/bin/env bash
# Makes the job-lead feature visible on Test Owner's business.
#
# The feature was already built and tested; what was missing was anything to use it on. This
# business has 35 orders and only 7 with any crew, and every CONFIRMED one had none — so opening an
# order showed no crew section, and there was nothing to hold down. An invisible feature and a
# missing one look identical from the phone.
#
# Sets up two orders on purpose, so both halves can be seen:
#   ORDER A  crew accepted, NOBODY given a role yet  -> long-press a name to set one
#   ORDER B  crew accepted, one of them already lead -> the worker's start/finish buttons
#
# Everything goes through the real endpoints. Dates are moved in the database because the rule
# being shown is about who may start a job, not about waiting for Saturday.
API=${API:-http://localhost:5056/api/v1}
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-100; }
ok()  { PASS=$((PASS+1)); printf 'PASS  %-52s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-52s %s\n' "$1" "$2"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }
want_ok() { if echo "$2" | grep -q '"success":true'; then ok "$1" "$3"; else bad "$1" "$(echo "$2" | msg)"; fi; }

post_() { local b="$3"; if [ -z "$b" ]; then b='{}'; fi
  curl -s -X POST "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$b"; }
put_()  { curl -s -X PUT "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$3"; }
login() { curl -s -X POST $API/auth/login -H 'Content-Type: application/json' \
            -d "{\"emailOrPhone\":\"$1\",\"password\":\"E2e@12345\"}" | j accessToken; }

BIZ='0252ffb3-568f-44b2-a7ef-fc58acedb347'

echo "================ SIGNING IN ================"
BT=$(login owner@zuno.local)
PT=$(login supervisor@zuno.local)
WT=$(login w1@zuno.local)
eq "Owner"       "$([ -n "$BT" ] && echo yes)" "yes"
eq "Priya"       "$([ -n "$PT" ] && echo yes)" "yes"
eq "Ravi"        "$([ -n "$WT" ] && echo yes)" "yes"
[ -n "$BT" ] && [ -n "$PT" ] && [ -n "$WT" ] || { echo "ABORTED: sign-in failed"; exit 1; }

PRIYA=$(sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='supervisor@zuno.local'")
RAVI=$(sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='w1@zuno.local'")

# Two confirmed orders with nobody on them. Picked rather than created so this uses the customer's
# real orders, which is what the owner will actually be looking at.
read -r ORDER_A ORDER_B <<<"$(sql "
  select string_agg(id::text, ' ') from (
    select b.id from bookings b
    where b.business_owner_profile_id='$BIZ' and b.booking_status=6 and b.is_deleted=false
      and not exists (select 1 from booking_worker_assignments a
                      where a.booking_id=b.id and a.is_deleted=false)
    order by b.scheduled_date limit 2) t")"
eq "Two empty confirmed orders found" "$([ -n "$ORDER_A" ] && [ -n "$ORDER_B" ] && echo yes)" "yes"
[ -n "$ORDER_A" ] && [ -n "$ORDER_B" ] || { echo "ABORTED: no empty confirmed orders"; exit 1; }

# Their day has come, so "Start this job" is offered rather than refused for the date.
sql "update bookings set scheduled_date = now() - interval '1 hour'
     where id in ('$ORDER_A','$ORDER_B')" >/dev/null

staff() {
  local order="$1" wp="$2" token="$3" who="$4"
  want_ok "$who assigned" "$(post_ /business/bookings/$order/assign-worker "$BT" "{\"workerProfileId\":\"$wp\"}")" ""
  want_ok "$who accepted" "$(post_ /worker/jobs/$order/respond "$token" '{"accept":true}')" ""
}

echo
echo "================ ORDER A — nobody is lead yet ================"
echo "  $ORDER_A"
staff "$ORDER_A" "$PRIYA" "$PT" "Priya"
staff "$ORDER_A" "$RAVI"  "$WT" "Ravi"
eq "Crew on it, no role on anyone" \
   "$(sql "select count(*) from booking_worker_assignments where booking_id='$ORDER_A' and role is not null and is_deleted=false")" "0"

echo
echo "================ ORDER B — Priya already leads it ================"
echo "  $ORDER_B"
staff "$ORDER_B" "$PRIYA" "$PT" "Priya"
staff "$ORDER_B" "$RAVI"  "$WT" "Ravi"
want_ok "Priya made Supervisor on this job" \
  "$(put_ /business/bookings/$ORDER_B/crew/$PRIYA/role "$BT" '{"role":"Supervisor"}')" "Supervisor"

echo
echo "================ PROVING IT FROM THE WORKERS' SIDE ================"
# Read back exactly what each worker's own screen will be given.
myrole() { curl -s "$API/worker/jobs/$1" -H "Authorization: Bearer $2" | grep -o '"myRole":[^,]*' | head -1 | cut -d: -f2; }
eq "Order B: Priya's screen says she is the lead" "$(myrole "$ORDER_B" "$PT")" '"Supervisor"'
eq "Order B: Ravi's screen says he is not"        "$(myrole "$ORDER_B" "$WT")" 'null'
eq "Order A: nobody leads it yet"                 "$(myrole "$ORDER_A" "$PT")" 'null'

echo
echo "================ WHAT TO DO ON THE PHONE ================"
cat <<EOF

  Sign in as the BUSINESS   owner@zuno.local / E2e@12345

    Orders -> open the order ending ${ORDER_A: -6}
      The Crew section now lists Priya and Ravi.
      LONG-PRESS either name -> set a role -> Save.
      A star appears on that row. Long-press again -> Remove role.

  Sign in as the WORKER     supervisor@zuno.local / E2e@12345   (Priya)

    My jobs -> open the job ending ${ORDER_B: -6}
      "You're the Supervisor on this job" + Start this job.

    My jobs -> open the job ending ${ORDER_A: -6}
      No banner, no start button — she leads that one only once you give her a role.

  Sign in as the WORKER     w1@zuno.local / E2e@12345           (Ravi)

    Same two jobs, no banner on either: he is crew, not lead.

EOF

echo "PASS $PASS   FAIL $FAIL"
[ "$FAIL" -eq 0 ]
