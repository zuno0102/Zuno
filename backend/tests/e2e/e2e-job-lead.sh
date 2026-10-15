#!/usr/bin/env bash
# The job lead: a role set on one order's crew, and what it does and does not let that worker do.
#
# The rule being proved:
#   * the owner names a lead on ONE job, from that order's crew
#   * the lead can start and finish THAT job
#   * an ordinary crew member on the same job cannot
#   * the lead cannot touch a different job they are also on
#   * removing the role takes the power away again
#
# That last pair is the whole reason the role lives on the assignment rather than on the person.
API=${API:-http://localhost:5056/api/v1}
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-105; }

ok()  { PASS=$((PASS+1)); printf 'PASS  %-55s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-55s %s\n' "$1" "$2"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }
has() { if echo "$2" | grep -qF "$3"; then ok "$1" "$3"; else bad "$1" "missing: $3"; fi; }
want_ok() { if echo "$2" | grep -q '"success":true'; then ok "$1" "$3"; else bad "$1" "$(echo "$2" | msg)"; fi; }
want_no() { if echo "$2" | grep -q '"success":false'; then ok "$1" "$(echo "$2" | msg)"; else bad "$1" "ALLOWED but should have been refused"; fi; }

PW='E2e@12345'
reg() {
  curl -s -X POST $API/auth/register -H 'Content-Type: application/json' \
    -d "{\"firstName\":\"$1\",\"lastName\":\"T\",\"email\":\"$2\",\"password\":\"$PW\",\"phoneNumber\":\"$3\",\"role\":\"$4\"}"
}
free_phone() {
  local c
  for _ in $(seq 1 50); do
    c="9$(shuf -i 100000000-999999999 -n 1)"
    [ -z "$(sql "select 1 from users where phone_number='$c'")" ] && { echo "$c"; return; }
  done
}
post_() { local b="$3"; if [ -z "$b" ]; then b='{}'; fi
  curl -s -X POST "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$b"; }
put_()  { curl -s -X PUT "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$3"; }
get_()  { curl -s "$API$1" -H "Authorization: Bearer $2"; }

echo "================ SETUP ================"
# Four registrations, inside the five-a-minute auth limit, and no logins.
BT=$(reg Boss "ld_b$S@zuno.local" "$(free_phone)" BusinessOwner | j accessToken)
CT=$(reg Cust "ld_c$S@zuno.local" "$(free_phone)" Customer | j accessToken)
LT=$(reg Ravi "ld_lead$S@zuno.local" "$(free_phone)" Worker | j accessToken)
WT=$(reg Anita "ld_hand$S@zuno.local" "$(free_phone)" Worker | j accessToken)
eq "Four accounts registered" "$([ -n "$BT" ] && [ -n "$CT" ] && [ -n "$LT" ] && [ -n "$WT" ] && echo yes)" "yes"
[ -n "$BT" ] && [ -n "$CT" ] && [ -n "$LT" ] && [ -n "$WT" ] || { echo "ABORTED"; exit 1; }

BIZ=$(sql "select b.id from business_owner_profiles b join users u on u.id=b.user_id where u.email='ld_b$S@zuno.local'")
sql "update business_owner_profiles set verification_status=1, verified_at=now() where id='$BIZ'" >/dev/null
DIST=$(sql "select id from districts limit 1")
LEAD_WP=$(sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='ld_lead$S@zuno.local'")
HAND_WP=$(sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='ld_hand$S@zuno.local'")

SVC=$(post_ /business/services "$BT" "{\"serviceCategoryId\":\"a1111111-0000-0000-0000-000000000003\",\"name\":\"Catering\",\"priceType\":\"Fixed\",\"price\":5000,\"requiredWorkerCount\":2,\"estimatedDurationMinutes\":120,\"districtIds\":[\"$DIST\"]}" | j id)

# Both workers onto the team.
for e in "ld_lead$S@zuno.local:$LT" "ld_hand$S@zuno.local:$WT"; do
  post_ /business/workers/invite "$BT" "{\"workerIdentifier\":\"${e%%:*}\"}" >/dev/null
  INV=$(get_ /worker/invitations "${e##*:}" | j id)
  post_ /worker/invitations/$INV/respond "${e##*:}" '{"accept":true}' >/dev/null
done
eq "Both workers on the team" "$(sql "select count(*) from business_workers where business_owner_profile_id='$BIZ' and assignment_status=2")" "2"

# Two orders, so "a lead on one job is not a lead on another" can be proved rather than assumed.
mk_booking() {
  post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$1\",\"addressLine1\":\"14 Nila Nagar\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"country\":\"India\"}" | j id
}
SAT=$(date -u -d '+2 days 10:00' +%Y-%m-%dT%H:%M:%SZ)
SUN=$(date -u -d '+9 days 10:00' +%Y-%m-%dT%H:%M:%SZ)
BK1=$(mk_booking "$SAT")
BK2=$(mk_booking "$SUN")
post_ /business/bookings/$BK1/confirm "$BT" >/dev/null
post_ /business/bookings/$BK2/confirm "$BT" >/dev/null
eq "Two orders confirmed" "$([ -n "$BK1" ] && [ -n "$BK2" ] && echo yes)" "yes"

# Crew on both. The same worker is on each, which is the point.
post_ /business/bookings/$BK1/assign-worker "$BT" "{\"workerProfileId\":\"$LEAD_WP\"}" >/dev/null
post_ /business/bookings/$BK1/assign-worker "$BT" "{\"workerProfileId\":\"$HAND_WP\"}" >/dev/null
post_ /business/bookings/$BK2/assign-worker "$BT" "{\"workerProfileId\":\"$LEAD_WP\"}" >/dev/null
post_ /worker/jobs/$BK1/respond "$LT" '{"accept":true}' >/dev/null
post_ /worker/jobs/$BK1/respond "$WT" '{"accept":true}' >/dev/null
post_ /worker/jobs/$BK2/respond "$LT" '{"accept":true}' >/dev/null

echo
echo "==== 1. Nobody leads anything until the owner says so ===="
eq "Nobody has a role yet" "$(sql "select count(*) from booking_worker_assignments where booking_id='$BK1' and role is not null")" "0"
sql "update bookings set scheduled_date=now() - interval '1 hour' where id='$BK1'" >/dev/null
want_no "A plain crew member cannot start the job" "$(post_ /worker/jobs/$BK1/start-job "$LT")"

echo
echo "==== 2. The owner names a lead, on this one job ===="
R=$(put_ /business/bookings/$BK1/crew/$LEAD_WP/role "$BT" '{"role":"Lead"}')
want_ok "Role set from the order's crew" "$R" "Lead"
has "...and comes back on the crew row" "$R" '"role":"Lead"'
eq "Stored against the assignment, not the person" \
   "$(sql "select role from booking_worker_assignments where booking_id='$BK1' and worker_profile_id='$LEAD_WP'")" "Lead"
eq "Nothing was written against the team member" \
   "$(sql "select count(*) from information_schema.columns where table_name='business_workers' and column_name='staff_role_id'")" "0"

echo
echo "==== 2b. The other two roles carry no power over the work ===="
# Only Lead can move the work. Supervisor watches it and Support fixes what it needs; three roles
# that could all declare a job started would mean nobody in particular was answerable for it.
# This script used to name a Supervisor and expect them to start the job, which was the rule
# during an earlier draft of the feature — it is not the rule now.
for ROLE in Supervisor Support; do
  put_ /business/bookings/$BK1/crew/$LEAD_WP/role "$BT" "{\"role\":\"$ROLE\"}" >/dev/null
  want_no "A $ROLE cannot start the work" "$(post_ /worker/jobs/$BK1/start-job "$LT")"
  eq     "...and the order has not moved" "$(sql "select booking_status from bookings where id='$BK1'")" "6"
done
R=$(put_ /business/bookings/$BK1/crew/$LEAD_WP/role "$BT" '{"role":"Lead"}')
want_ok "Named Lead again for what follows" "$R" "Lead"

echo
echo "==== 3. The lead can move THAT job ===="
want_ok "Lead starts the job" "$(post_ /worker/jobs/$BK1/start-job "$LT")" ""
eq "Order is in progress" "$(sql "select booking_status from bookings where id='$BK1'")" "3"
# The customer is told, and named as the person who actually did it.
eq "Customer was told once" \
   "$(get_ "/notifications?take=50" "$CT" | tr '}' '\n' | grep -c '"kind":"BookingWorkStarted"')" "1"
has "...naming the lead, not the business" \
   "$(get_ "/notifications?take=50" "$CT" | tr '}' '\n' | grep '"kind":"BookingWorkStarted"')" "Ravi T has started your job"

echo
echo "==== 4. An ordinary crew member on the same job still cannot ===="
want_no "The other worker cannot finish the job" "$(post_ /worker/jobs/$BK1/finish-job "$WT")"
eq "Order is still in progress" "$(sql "select booking_status from bookings where id='$BK1'")" "3"

echo
echo "==== 5. A lead on one job is not a lead on another ===="
sql "update bookings set scheduled_date=now() - interval '1 hour' where id='$BK2'" >/dev/null
want_no "Same worker cannot start the job they do not lead" "$(post_ /worker/jobs/$BK2/start-job "$LT")"
eq "That order has not moved" "$(sql "select booking_status from bookings where id='$BK2'")" "6"

echo
echo "==== 6. Only the owner hands a role out ===="
# A worker hitting a business-only route is turned away by the policy, which answers 403 with NO
# BODY. Asserted on the status code: looking for "success":false in an empty response reports a
# refusal as an allow, which is exactly the wrong way round for a security check.
eq "A lead cannot appoint another lead" \
   "$(curl -s -o /dev/null -w '%{http_code}' -X PUT "$API/business/bookings/$BK1/crew/$HAND_WP/role" -H "Authorization: Bearer $LT" -H 'Content-Type: application/json' -d '{"role":"Lead"}')" "403"
eq "Unauthenticated is refused" \
   "$(curl -s -o /dev/null -w '%{http_code}' -X PUT "$API/business/bookings/$BK1/crew/$HAND_WP/role" -H 'Content-Type: application/json' -d '{"role":"Lead"}')" "401"

echo
echo "==== 7. The lead finishes the job ===="
want_ok "Lead finishes the job" "$(post_ /worker/jobs/$BK1/finish-job "$LT")" ""
eq "Order is completed" "$(sql "select booking_status from bookings where id='$BK1'")" "4"
eq "The whole crew was finished with it" \
   "$(sql "select count(*) from booking_worker_assignments where booking_id='$BK1' and assignment_status=4")" "2"

echo
echo "==== 8. Taking the role away takes the power with it ===="
R=$(put_ /business/bookings/$BK2/crew/$LEAD_WP/role "$BT" '{"role":"Lead"}')
want_ok "Named lead on the second job" "$R" "Lead"
want_ok "...so now they can start it" "$(post_ /worker/jobs/$BK2/start-job "$LT")" ""

R=$(put_ /business/bookings/$BK2/crew/$LEAD_WP/role "$BT" '{"role":""}')
want_ok "Role removed with a blank" "$R" ""
eq "Cleared in the database" \
   "$(sql "select coalesce(role,'(none)') from booking_worker_assignments where booking_id='$BK2' and worker_profile_id='$LEAD_WP'")" "(none)"
want_no "They can no longer finish the job" "$(post_ /worker/jobs/$BK2/finish-job "$LT")"

echo
echo "==== 9. A role cannot be pinned on somebody who refused the job ===="
BK3=$(mk_booking "$(date -u -d '+20 days 10:00' +%Y-%m-%dT%H:%M:%SZ)")
post_ /business/bookings/$BK3/confirm "$BT" >/dev/null
post_ /business/bookings/$BK3/assign-worker "$BT" "{\"workerProfileId\":\"$HAND_WP\"}" >/dev/null
post_ /worker/jobs/$BK3/respond "$WT" '{"accept":false}' >/dev/null
want_no "Refused: that worker turned the job down" \
  "$(put_ /business/bookings/$BK3/crew/$HAND_WP/role "$BT" '{"role":"Lead"}')"

want_no "Refused: that worker is not on this job at all" \
  "$(put_ /business/bookings/$BK3/crew/$LEAD_WP/role "$BT" '{"role":"Lead"}')"

echo
echo "PASS $PASS   FAIL $FAIL"
[ "$FAIL" -eq 0 ]
