#!/usr/bin/env bash
# Business home counts: the Orders finished card, and the Active workers tile.
API=http://localhost:5056/api/v1
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-90; }

ok()  { PASS=$((PASS+1)); printf 'PASS  %-52s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-52s %s\n' "$1" "$2"; }
want_ok() { if echo "$2" | grep -q '"success":true'; then ok "$1" "$3"; else bad "$1" "$(echo "$2" | msg)"; fi; }
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

# One top-level numeric field off the dashboard.
num() { echo "$1" | grep -o "\"$2\":[0-9]*" | head -1 | cut -d: -f2; }
# How many objects one dashboard array holds. Counts "id"/"workerProfileId" keys inside the
# slice rather than commas, which appear inside every row too.
rows() { echo "$1" | grep -o "\"$2\":\[[^]]*\]" | head -1 | grep -o "\"$3\":" | wc -l | tr -d ' '; }

echo "================ SETUP ================"
BT=$(reg Boss "db_b$S@zuno.local" BusinessOwner | j accessToken)
CT=$(reg Cust "db_c$S@zuno.local" Customer | j accessToken)
W1=$(reg Wone "db_w1$S@zuno.local" Worker | j accessToken)
W2=$(reg Wtwo "db_w2$S@zuno.local" Worker | j accessToken)
if [ -z "$BT" ] || [ -z "$CT" ] || [ -z "$W1" ] || [ -z "$W2" ]; then
  echo "registration failed (rate limit?)"; exit 1
fi
ok "Registered business, customer, 2 workers" "db_b$S@zuno.local"

BIZ=$(sql "select b.id from business_owner_profiles b join users u on u.id=b.user_id where u.email='db_b$S@zuno.local'")
sql "update business_owner_profiles set verification_status=1, verified_at=now() where id='$BIZ'" >/dev/null
DIST=$(sql "select id from districts limit 1")
CAT=a1111111-0000-0000-0000-000000000003

SVC=$(post_ /business/services "$BT" "{\"serviceCategoryId\":\"$CAT\",\"name\":\"Catering\",\"priceType\":\"Fixed\",\"price\":5000,\"requiredWorkerCount\":1,\"districtIds\":[\"$DIST\"]}" | j id)
eq "Service created" "$([ -n "$SVC" ] && echo yes)" "yes"

WHEN=$(date -u -d '+10 days 10:00' +%Y-%m-%dT%H:%M:%SZ)
mk() { post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$WHEN\",\"addressLine1\":\"14 Nila Nagar\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"latitude\":10.5276,\"longitude\":76.2144,\"country\":\"India\"}" | j id; }

# 3 completed, 1 cancelled, 2 still upcoming.
D1=$(mk); D2=$(mk); D3=$(mk); X1=$(mk); U1=$(mk); U2=$(mk)
for B in $D1 $D2 $D3 $U1 $U2; do post_ /business/bookings/$B/confirm "$BT" >/dev/null; done
sql "update bookings set booking_status=4, completed_at=now() - interval '2 days' where id in ('$D1','$D2')" >/dev/null
sql "update bookings set booking_status=4, completed_at=now() where id='$D3'" >/dev/null
want_ok "Customer cancels one order" "$(post_ /customer/bookings/$X1/cancel "$CT" '{"cancellationReason":"Changed plans"}')" ""

echo
echo "==== 1. THE ORDERS FINISHED CARD ===="
D=$(get_ /business/dashboard "$BT")
eq "Counts 3 finished"                  "$(num "$D" eventsCompleted)" "3"
eq "Counts 2 upcoming"                  "$(num "$D" upcomingEvents)"  "2"
eq "Counts 1 cancelled"                 "$(num "$D" cancelledEvents)" "1"

echo
echo "==== 2. THE ACTIVE WORKERS TILE ===="
eq "Nobody on the roster yet"           "$(num "$D" activeWorkers)"   "0"
eq "...and no rows to show"             "$(rows "$D" workers workerProfileId)" "0"

# Invited but unanswered must not count — the tile says who can be put on a job.
want_ok "Worker 1 invited" "$(post_ /business/workers/invite "$BT" "{\"workerIdentifier\":\"db_w1$S@zuno.local\"}")" ""
D=$(get_ /business/dashboard "$BT")
eq "An unanswered invitation does not count" "$(num "$D" activeWorkers)" "0"

INV=$(get_ /worker/invitations "$W1" | j id)
want_ok "Worker 1 accepts" "$(post_ /worker/invitations/$INV/respond "$W1" '{"accept":true}')" ""
D=$(get_ /business/dashboard "$BT")
eq "Accepting puts them on the roster" "$(num "$D" activeWorkers)" "1"
eq "...and ships one row"              "$(rows "$D" workers workerProfileId)" "1"

AV=$(echo "$D" | grep -o '"availabilityStatus":"[^"]*"' | head -1 | cut -d'"' -f4)
eq "They read as free"                 "$AV" "Active"
eq "With no jobs behind them yet"      "$(echo "$D" | grep -o '"jobsCompleted":[0-9]*' | head -1 | cut -d: -f2)" "0"

echo
echo "==== 3. EXPERIENCE COUNTS THIS BUSINESS'S OWN COMPLETED JOBS ===="
WP1=$(sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='db_w1$S@zuno.local'")
# Two jobs they actually turned up to: assignment_status 2 = Accepted, 4 = Completed.
# The insert is checked rather than assumed — a silently rejected one reads exactly like a
# handler that counts nothing, and did on the first run of this script.
# head -1 takes the returned row; psql prints its "INSERT 0 1" tag on the line after.
ins() { sql "insert into booking_worker_assignments (id, booking_id, worker_profile_id, assignment_status, responded_at, created_date, is_deleted, status) values (gen_random_uuid(),'$1','$2',$3,now(),now(),false,1) returning 1" | head -1; }
eq "Two assignment rows written" "$(ins "$D1" "$WP1" 2)$(ins "$D2" "$WP1" 4)" "11"

D=$(get_ /business/dashboard "$BT")
eq "Two finished jobs are credited" "$(echo "$D" | grep -o '"jobsCompleted":[0-9]*' | head -1 | cut -d: -f2)" "2"

# A job they were offered and turned down is not experience.
eq "A declined assignment written" "$(ins "$D3" "$WP1" 3)" "1"
D=$(get_ /business/dashboard "$BT")
eq "A job they turned down is not credited" "$(echo "$D" | grep -o '"jobsCompleted":[0-9]*' | head -1 | cut -d: -f2)" "2"

echo
echo "==== 3b. A BOOKED WORKER REPORTS *WHEN* THEY ARE BUSY ===="
# "Booked" alone reads the same for this afternoon and for March. Put them on one of the
# upcoming orders and the tile must name its date.
eq "An upcoming assignment written" "$(ins "$U1" "$WP1" 2)" "1"
D=$(get_ /business/dashboard "$BT")
AV=$(echo "$D" | grep -o '"availabilityStatus":"[^"]*"' | head -1 | cut -d'"' -f4)
eq "They now read as Booked" "$AV" "Booked"
BUSY=$(echo "$D" | grep -o '"busyOn":"[^"]*"' | head -1 | cut -d'"' -f4 | cut -c1-10)
eq "busyOn is the order's own date" "$BUSY" "$(date -u -d '+10 days' +%Y-%m-%d)"
# The work is never named. This diary spans every business the worker serves, so a job title
# here would show one business another's customers.
if echo "$D" | grep -q '"busyWith"'; then
  bad "Names no job, only the date"   "busyWith is back on the dashboard"
else
  ok "Names no job, only the date"    "date only"
fi

echo
echo "==== 3c. THE WORKERS TAB SAYS WHETHER, NOT WHEN ===="
# The row carries availability alone. A single date there could only ever show the first of
# however many jobs a worker holds, so the dates live in the schedule endpoint instead.
W=$(get_ /business/workers "$BT")
eq "Workers tab reports Booked" "$(echo "$W" | grep -o '"availabilityStatus":"[^"]*"' | head -1 | cut -d'"' -f4)" "Booked"
if echo "$W" | grep -qE '"busyOn"|"busyWith"'; then
  bad "Carries no date of its own" "a date field is still on /business/workers"
else
  ok "Carries no date of its own" "status only"
fi
# ...and the schedule endpoint is where they actually are. Only the upcoming order shows: this
# worker's three earlier assignments all sit on completed bookings, which release them.
SCHED=$(get_ /business/workers/$WP1/busy-dates "$BT")
eq "The schedule holds the live job"     "$(echo "$SCHED" | grep -o '"startsAt"' | wc -l | tr -d ' ')" "1"
eq "...dated to the upcoming order"      "$(echo "$SCHED" | grep -o '"startsAt":"[^"]*"' | head -1 | cut -d'"' -f4 | cut -c1-10)" "$(date -u -d '+10 days' +%Y-%m-%d)"
eq "...and finished work is not listed"  "$(echo "$SCHED" | grep -o '"startsAt":' | wc -l | tr -d ' ')" "1"

echo
echo "==== 4. REMOVED WORKERS DROP OFF THE TILE ===="
sql "update business_workers set assignment_status=4 where worker_profile_id='$WP1' and business_owner_profile_id='$BIZ'" >/dev/null
D=$(get_ /business/dashboard "$BT")
eq "A removed worker is no longer active" "$(num "$D" activeWorkers)" "0"

echo
echo "================ $PASS passed, $FAIL failed ================"
[ "$FAIL" -eq 0 ]
