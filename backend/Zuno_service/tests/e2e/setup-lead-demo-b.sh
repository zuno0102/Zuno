#!/usr/bin/env bash
# Order B for the job-lead demo: crew with a lead already named.
#
# Split from setup-lead-demo.sh after that script put both orders at the same hour and the clash
# check — correctly — refused to put the same two workers on both. Order B therefore uses DIFFERENT
# workers at a DIFFERENT time, which is also closer to the real thing: two jobs running the same
# day with two different crews and two different leads.
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

BT=$(login owner@zuno.local)
AT=$(login w2@zuno.local)   # Anita  — will be the lead
ST=$(login w3@zuno.local)   # Suresh — ordinary crew
eq "Owner signed in"  "$([ -n "$BT" ] && echo yes)" "yes"
eq "Anita signed in"  "$([ -n "$AT" ] && echo yes)" "yes"
eq "Suresh signed in" "$([ -n "$ST" ] && echo yes)" "yes"
[ -n "$BT" ] && [ -n "$AT" ] && [ -n "$ST" ] || { echo "ABORTED: sign-in failed"; exit 1; }

ANITA=$(sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='w2@zuno.local'")
SURESH=$(sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='w3@zuno.local'")

ORDER_B=$(sql "
  select b.id from bookings b
  where b.business_owner_profile_id='$BIZ' and b.booking_status=6 and b.is_deleted=false
    and not exists (select 1 from booking_worker_assignments a
                    where a.booking_id=b.id and a.is_deleted=false)
  order by b.scheduled_date limit 1")
eq "An empty confirmed order found" "$([ -n "$ORDER_B" ] && echo yes)" "yes"
[ -n "$ORDER_B" ] || { echo "ABORTED"; exit 1; }

# Earlier in the day than order A, so the two crews do not overlap in the clash check.
sql "update bookings set scheduled_date = now() - interval '6 hours' where id='$ORDER_B'" >/dev/null

echo
echo "================ ORDER B ================"
echo "  $ORDER_B"
want_ok "Anita assigned"  "$(post_ /business/bookings/$ORDER_B/assign-worker "$BT" "{\"workerProfileId\":\"$ANITA\"}")" ""
want_ok "Anita accepted"  "$(post_ /worker/jobs/$ORDER_B/respond "$AT" '{"accept":true}')" ""
want_ok "Suresh assigned" "$(post_ /business/bookings/$ORDER_B/assign-worker "$BT" "{\"workerProfileId\":\"$SURESH\"}")" ""
want_ok "Suresh accepted" "$(post_ /worker/jobs/$ORDER_B/respond "$ST" '{"accept":true}')" ""
want_ok "Anita made Supervisor on this job" \
  "$(put_ /business/bookings/$ORDER_B/crew/$ANITA/role "$BT" '{"role":"Supervisor"}')" "Supervisor"

echo
echo "================ AS EACH WORKER'S SCREEN WILL SEE IT ================"
myrole() { curl -s "$API/worker/jobs/$1" -H "Authorization: Bearer $2" | grep -o '"myRole":[^,]*' | head -1 | cut -d: -f2; }
eq "Anita leads this job"      "$(myrole "$ORDER_B" "$AT")" '"Supervisor"'
eq "Suresh is crew, not lead"  "$(myrole "$ORDER_B" "$ST")" 'null'

echo
echo "  Order B: $ORDER_B  (ends ${ORDER_B: -6})"
echo "  Lead: w2@zuno.local (Anita)   Crew: w3@zuno.local (Suresh)   Password: E2e@12345"
echo
echo "PASS $PASS   FAIL $FAIL"
[ "$FAIL" -eq 0 ]
