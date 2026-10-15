#!/usr/bin/env bash
# The five tracks on one order, one assertion per arrow in the chain.
#
#   ORDER   Pending -confirm-> Active -(the date arrives)-> In progress -> Completed
#   CREW    hired, counted from the assignment rows
#   WORK    Not started -Start work-> In progress -Mark completed-> Completed
#   WAGES   Outstanding -Pay all-> Settled   (or NoWagesThroughZuno when none are owed)
#   WHOLE   work Completed AND wages clear  ->  completed count +1
#
# The two that matter most: the order reads In progress from the DATE without anything being
# tapped, and the count does NOT rise while a wage is outstanding.
API=http://localhost:5056/api/v1
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-100; }

ok()  { PASS=$((PASS+1)); printf 'PASS  %-56s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-56s %s\n' "$1" "$2"; }
want_ok() { if echo "$2" | grep -q '"success":true'; then ok "$1" "$3"; else bad "$1" "$(echo "$2" | msg)"; fi; }
want_no() { if echo "$2" | grep -q '"success":false'; then ok "$1" "$(echo "$2" | msg)"; else bad "$1" "ALLOWED but should have been refused"; fi; }
eq()      { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }

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
post_() { local b="$3"; if [ -z "$b" ]; then b='{}'; fi
  curl -s -X POST "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$b"; }
get_()  { curl -s "$API$1" -H "Authorization: Bearer $2"; }

# One order as the business sees it, and the figures off it.
order()   { get_ /business/bookings/$1 "$BT"; }
field()   { echo "$1" | grep -o "\"$2\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
dbstatus(){ sql "select booking_status from bookings where id='$1'"; }
counted() { sql "select completed_job_count from business_owner_profiles where id='$BIZ'"; }

echo "================ SETUP ================"
BT=$(reg Boss "ol_b$S@zuno.local" BusinessOwner | j accessToken)
CT=$(reg Cust "ol_c$S@zuno.local" Customer | j accessToken)
W1=$(reg Ravi "ol_w1$S@zuno.local" Worker | j accessToken)
if [ -z "$BT" ] || [ -z "$CT" ] || [ -z "$W1" ]; then echo "registration failed (rate limit?)"; exit 1; fi
ok "Registered business, customer, worker" "ol_b$S@zuno.local"

BIZ=$(sql "select b.id from business_owner_profiles b join users u on u.id=b.user_id where u.email='ol_b$S@zuno.local'")
sql "update business_owner_profiles set verification_status=1, verified_at=now() where id='$BIZ'" >/dev/null
DIST=$(sql "select id from districts limit 1")
WP=$(sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='ol_w1$S@zuno.local'")

SVC=$(post_ /business/services "$BT" "{\"serviceCategoryId\":\"a1111111-0000-0000-0000-000000000003\",\"name\":\"Catering\",\"priceType\":\"Fixed\",\"price\":5000,\"requiredWorkerCount\":1,\"estimatedDurationMinutes\":120,\"districtIds\":[\"$DIST\"]}" | j id)
eq "Service created" "$([ -n "$SVC" ] && echo yes)" "yes"
eq "Nothing counted yet" "$(counted)" "0"

FUTURE=$(date -u -d '+20 days 10:00' +%Y-%m-%dT%H:%M:%SZ)
BK=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$FUTURE\",\"addressLine1\":\"14 Nila Nagar\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"country\":\"India\"}" | j id)
eq "Customer placed the order" "$([ -n "$BK" ] && echo yes)" "yes"

echo
echo "==== 1. ORDER: Pending -> Active ===="
eq "Starts Pending (1)" "$(dbstatus $BK)" "1"
want_ok "Business confirms it" "$(post_ /business/bookings/$BK/confirm "$BT")" ""
eq "Stored as Confirmed (6)" "$(dbstatus $BK)" "6"
# "Active" is the label the app puts on Confirmed before the day; no new stored value.
eq "Work has not started"  "$(order $BK | grep -o '"workStartedAt":[^,}]*' | head -1 | cut -d: -f2)" "null"

echo
echo "==== 2. NOTHING STARTS EARLY ===="
want_no "Start work refused 20 days out" "$(post_ /business/bookings/$BK/start "$BT")"
# ...and it is refused for the date, not for want of a crew: put someone on first.
want_ok "Worker joins the roster" "$(post_ /business/workers/invite "$BT" "{\"workerIdentifier\":\"ol_w1$S@zuno.local\"}")" ""
INV=$(get_ /worker/invitations "$W1" | j id)
post_ /worker/invitations/$INV/respond "$W1" '{"accept":true}' >/dev/null
want_ok "Worker assigned to the order" "$(post_ /business/bookings/$BK/assign-worker "$BT" "{\"workerProfileId\":\"$WP\"}")" ""
sql "update booking_worker_assignments set assignment_status=2, responded_at=now() where booking_id='$BK'" >/dev/null
want_no "Still refused, with a crew on it" "$(post_ /business/bookings/$BK/start "$BT")"

echo
echo "==== 3. ORDER: the DATE moves it, not a button ===="
sql "update bookings set scheduled_date=now() - interval '1 hour' where id='$BK'" >/dev/null
# The stored status has not moved and nothing was tapped — the app reads Confirmed + past its
# time as "In progress". That is the whole point of deriving it.
eq "Still stored as Confirmed (6)" "$(dbstatus $BK)" "6"
eq "...and still not started"      "$(order $BK | grep -o '"workStartedAt":[^,}]*' | head -1 | cut -d: -f2)" "null"

echo
echo "==== 4. WORK: Start work moves the work, and the crew with it ===="
R=$(post_ /business/bookings/$BK/start "$BT")
want_ok "Start work accepted now the day has come" "$R" ""
eq "Order InProgress (3)"   "$(dbstatus $BK)" "3"
eq "Work start stamped"     "$(order $BK | grep -o '"workStartedAt":"[^"]*"' | head -1 | cut -d'"' -f4 | cut -c1-4)" "$(date -u +%Y)"
eq "The worker reads InProgress" "$(order $BK | grep -o '"displayStatus":"[^"]*"' | head -1 | cut -d'"' -f4)" "InProgress"
want_no "Cannot start twice" "$(post_ /business/bookings/$BK/start "$BT")"

echo
echo "==== 4b. A WORKER MID-JOB TAKES NOTHING ELSE ===="
# For the worker's sake. Work that has started has no reliable end — a two-hour job can run
# five — so the clock cannot say they are free. Somebody has to say the job is done.
FAR=$(date -u -d '+40 days 10:00' +%Y-%m-%dT%H:%M:%SZ)
BKX=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$FAR\",\"addressLine1\":\"14 Nila Nagar\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"country\":\"India\"}" | j id)
post_ /business/bookings/$BKX/confirm "$BT" >/dev/null
# 40 days away, so no overlap and no travel-buffer problem — only the unfinished job stands in
# the way. Without the new rule this would be allowed.
want_no "Refused: still on an unfinished job" "$(post_ /business/bookings/$BKX/assign-worker "$BT" "{\"workerProfileId\":\"$WP\"}")"

echo
echo "==== 5. WORK: the business closes it ===="
want_ok "Mark completed accepted" "$(post_ /business/bookings/$BK/complete "$BT")" ""
eq "Order Completed (4)"          "$(dbstatus $BK)" "4"
eq "The crew is finished too"     "$(sql "select count(*) from booking_worker_assignments where booking_id='$BK' and assignment_status=4")" "1"
want_no "Cannot complete twice"   "$(post_ /business/bookings/$BK/complete "$BT")"
# ...and closing it frees the worker, which is the point of the rule above.
want_ok "Now free for the next job" "$(post_ /business/bookings/$BKX/assign-worker "$BT" "{\"workerProfileId\":\"$WP\"}")" ""

echo
echo "==== 6. WAGES: roster crew owe nothing, so the order counts ===="
# Nobody was hired through the app for this one. There is no payment that could ever arrive, so
# treating it as pending would leave the order waiting for ever.
eq "Reads as owing nothing" "$(field "$(order $BK)" wageStatus)" "NoWagesThroughZuno"
eq "Counted on the profile" "$(counted)" "1"

echo
echo "==== 7. A SECOND ORDER, HIRED THROUGH ZUNO ===="
W2=$(reg Anita "ol_w2$S@zuno.local" Worker | j accessToken)
WP2=$(sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='ol_w2$S@zuno.local'")
SOON=$(date -u -d '+2 hours' +%Y-%m-%dT%H:%M:%SZ)
BK2=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$SOON\",\"addressLine1\":\"14 Nila Nagar\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"country\":\"India\"}" | j id)
post_ /business/bookings/$BK2/confirm "$BT" >/dev/null

P=$(post_ /business/hiring-posts "$BT" "{\"bookingId\":\"$BK2\",\"title\":\"Crew for the order\",\"eventDate\":\"$SOON\",\"durationMinutes\":120,\"workersNeeded\":1,\"salaryAmount\":900,\"salaryUnit\":\"PerEvent\",\"location\":\"14 Nila Nagar\"}" | j id)
want_ok "Hiring raised against the order" "$(post_ /business/hiring-posts/$P/invite "$BT" "{\"workerIdentifier\":\"ol_w2$S@zuno.local\"}")" ""
PA=$(sql "select a.id from hiring_post_applications a where a.hiring_post_id='$P' and a.worker_profile_id='$WP2' and a.is_deleted=false limit 1")
want_ok "Worker accepts, landing on the order" "$(post_ /worker/hiring-posts/applications/$PA/respond "$W2" '{"accept":true}')" ""
eq "Wages now outstanding" "$(field "$(order $BK2)" wageStatus)" "Outstanding"

sql "update bookings set scheduled_date=now() - interval '1 hour' where id='$BK2'" >/dev/null
want_ok "Started"          "$(post_ /business/bookings/$BK2/start "$BT")" ""
want_ok "Marked completed" "$(post_ /business/bookings/$BK2/complete "$BT")" ""
eq "Order Completed (4)"   "$(dbstatus $BK2)" "4"

echo
echo "==== 8. THE COUNT WAITS FOR THE WAGES ===="
# The half of the chain that is easy to get wrong: finished work with money still owed is not a
# finished job.
eq "Still owing"                     "$(field "$(order $BK2)" wageStatus)" "Outstanding"
eq "So the count has NOT risen"      "$(counted)" "1"

# Pay outside the app, then let the worker confirm it arrived — the path that does not need a
# live Razorpay call.
sql "update hiring_post_applications set payment_status=6 where id='$PA'" >/dev/null
sql "update hiring_posts set work_completed_at=now() where id='$P'" >/dev/null
# This one answers 204 with no body, so the row is what says it worked. 3 = Paid.
post_ /worker/hiring-posts/applications/$PA/payment-response "$W2" '{"received":true}' >/dev/null
eq "Worker confirms the wage arrived" "$(sql "select payment_status from hiring_post_applications where id='$PA'")" "3"
eq "Wages now settled"  "$(field "$(order $BK2)" wageStatus)" "Settled"
eq "NOW the count rises" "$(counted)" "2"

echo
echo "==== 9. ONE JOB, COUNTED ONCE ===="
# The order and the post raised for it are the same piece of work. Counting the post separately
# would credit this wedding twice.
eq "Two orders, two credits — not three" "$(counted)" "2"
eq "...and the post is linked, not standalone" "$(sql "select count(*) from hiring_posts where id='$P' and booking_id is not null")" "1"

echo
echo "================ $PASS passed, $FAIL failed ================"
[ "$FAIL" -eq 0 ]
