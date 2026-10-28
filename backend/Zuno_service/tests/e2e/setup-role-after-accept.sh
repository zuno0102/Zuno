#!/usr/bin/env bash
# Data for the rule "a role can only be given once the worker has accepted the job".
#
# One order carrying BOTH states at once, because the rule is only visible as a contrast:
#
#   Priya   ACCEPTED  -> long-press works, she can be made Supervisor
#   Ravi    ACCEPTED  -> same
#   Beautlin ASSIGNED -> long-press does nothing; the server refuses too
#
# Without somebody in the un-answered state on the same screen, "you cannot do it yet" is
# indistinguishable from "this feature is broken" — which is exactly how the last one looked.
API=${API:-http://localhost:5056/api/v1}
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-95; }
ok()  { PASS=$((PASS+1)); printf 'PASS  %-50s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-50s %s\n' "$1" "$2"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }
want_ok() { if echo "$2" | grep -q '"success":true'; then ok "$1" "$3"; else bad "$1" "$(echo "$2" | msg)"; fi; }
want_no() { if echo "$2" | grep -q '"success":false'; then ok "$1" "$(echo "$2" | msg)"; else bad "$1" "ALLOWED but should have been refused"; fi; }

post_() { local b="$3"; if [ -z "$b" ]; then b='{}'; fi
  curl -s -X POST "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$b"; }
put_()  { curl -s -X PUT "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$3"; }
login() { curl -s -X POST $API/auth/login -H 'Content-Type: application/json' \
            -d "{\"emailOrPhone\":\"$1\",\"password\":\"E2e@12345\"}" | j accessToken; }

BIZ='0252ffb3-568f-44b2-a7ef-fc58acedb347'

BT=$(login owner@zuno.local)
eq "Owner signed in" "$([ -n "$BT" ] && echo yes)" "yes"
[ -n "$BT" ] || { echo "ABORTED"; exit 1; }

# The order set up earlier, where Priya and Ravi have already accepted.
ORDER=$(sql "
  select b.id from bookings b
  join booking_worker_assignments a on a.booking_id=b.id and a.is_deleted=false
  join worker_profiles wp on wp.id=a.worker_profile_id
  join users u on u.id=wp.user_id
  where b.business_owner_profile_id='$BIZ' and b.booking_status=6
    and u.email='supervisor@zuno.local' and a.assignment_status=2
  order by b.scheduled_date desc limit 1")
eq "Found the order with accepted crew" "$([ -n "$ORDER" ] && echo yes)" "yes"
[ -n "$ORDER" ] || { echo "ABORTED: run setup-lead-demo.sh first"; exit 1; }

BEAUT=$(sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='worker@zuno.local'")
PRIYA=$(sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='supervisor@zuno.local'")

echo
echo "================ ADDING AN UN-ANSWERED CREW MEMBER ================"
if [ -z "$(sql "select 1 from booking_worker_assignments where booking_id='$ORDER' and worker_profile_id='$BEAUT' and is_deleted=false")" ]; then
  want_ok "Beautlin assigned (and deliberately not accepted)" \
    "$(post_ /business/bookings/$ORDER/assign-worker "$BT" "{\"workerProfileId\":\"$BEAUT\"}")" ""
else
  ok "Beautlin already on this order" ""
fi
eq "Still waiting on their answer" \
   "$(sql "select assignment_status from booking_worker_assignments where booking_id='$ORDER' and worker_profile_id='$BEAUT' and is_deleted=false")" "1"

echo
echo "================ THE RULE, BOTH WAYS ================"
want_no "A role is refused before they answer" \
  "$(put_ /business/bookings/$ORDER/crew/$BEAUT/role "$BT" '{"role":"Supervisor"}')"
eq "...and nothing was written" \
   "$(sql "select coalesce(role,'(none)') from booking_worker_assignments where booking_id='$ORDER' and worker_profile_id='$BEAUT'")" "(none)"

want_ok "A role is allowed once they have" \
  "$(put_ /business/bookings/$ORDER/crew/$PRIYA/role "$BT" '{"role":"Supervisor"}')" "Supervisor"

# Put it back, so the screen opens with the role still to be given — which is the thing to try.
want_ok "Cleared again, ready to set from the phone" \
  "$(put_ /business/bookings/$ORDER/crew/$PRIYA/role "$BT" '{"role":""}')" ""

echo
echo "================ THE CREW ON THAT ORDER ================"
"$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -F' | ' -c "
select u.first_name,
       case a.assignment_status when 1 then 'Assigned (not answered)' when 2 then 'Accepted'
            when 3 then 'Declined' when 4 then 'Completed' end,
       coalesce(a.role,'-')
from booking_worker_assignments a
join worker_profiles wp on wp.id=a.worker_profile_id join users u on u.id=wp.user_id
where a.booking_id='$ORDER' and a.is_deleted=false order by a.assignment_status;" 2>&1 | tr -d '\r'

echo
echo "  Order: $ORDER  (ends ${ORDER: -6})"
echo "  owner@zuno.local / E2e@12345  ->  Orders -> that order -> Crew"
echo "    long-press Priya or Ravi  -> the role sheet opens"
echo "    long-press Beautlin       -> nothing, until they accept"
echo
echo "PASS $PASS   FAIL $FAIL"
[ "$FAIL" -eq 0 ]
