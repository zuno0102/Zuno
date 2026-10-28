#!/usr/bin/env bash
# The availability badge and the schedule behind it must always agree.
#
# They used to be built from different queries, and disagreed in both directions:
#   * a worker held only by a HIRING POST read as free, yet their schedule listed jobs;
#   * a worker on a CANCELLED booking read as booked forever, yet their schedule was empty.
# Both now come from IWorkerScheduleService.GetCommitmentsAsync, so every scenario below checks
# the badge and the dates together rather than one at a time.
#
# Also covered: several dates, several jobs on one date, two jobs at the identical minute, and
# the rule that the schedule reports times only — never what the work is.
API=${API:-http://localhost:5056/api/v1}
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

# The badge on the workers list, and the schedule behind it.
badge() { get_ /business/workers "$BT" | tr '{' '\n' | grep "\"workerProfileId\":\"$WP\"" | grep -o '"availabilityStatus":"[^"]*"' | head -1 | cut -d'"' -f4; }
sched() { get_ /business/workers/$WP/busy-dates "$BT"; }
slots() { echo "$1" | grep -o '"startsAt"' | wc -l | tr -d ' '; }

# Every scenario asserts the pair, because the bug was them disagreeing.
agree() {
  local label="$1" expect_badge="$2" expect_slots="$3"
  local b s n
  b=$(badge); s=$(sched); n=$(slots "$s")
  if [ "$b" = "$expect_badge" ] && [ "$n" = "$expect_slots" ]; then
    ok "$label" "$b, $n slot(s)"
  else
    bad "$label" "badge='$b' slots=$n, expected '$expect_badge' and $expect_slots"
  fi
}

echo "================ SETUP ================"
BT=$(reg Boss "wc_b$S@zuno.local" BusinessOwner | j accessToken)
CT=$(reg Cust "wc_c$S@zuno.local" Customer | j accessToken)
W1=$(reg Ravi "wc_w1$S@zuno.local" Worker | j accessToken)
if [ -z "$BT" ] || [ -z "$CT" ] || [ -z "$W1" ]; then echo "registration failed (rate limit?)"; exit 1; fi
ok "Registered business, customer, worker" "wc_b$S@zuno.local"

BIZ=$(sql "select b.id from business_owner_profiles b join users u on u.id=b.user_id where u.email='wc_b$S@zuno.local'")
sql "update business_owner_profiles set verification_status=1, verified_at=now() where id='$BIZ'" >/dev/null
DIST=$(sql "select id from districts limit 1")
WP=$(sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='wc_w1$S@zuno.local'")

SVC=$(post_ /business/services "$BT" "{\"serviceCategoryId\":\"a1111111-0000-0000-0000-000000000003\",\"name\":\"Catering\",\"priceType\":\"Fixed\",\"price\":5000,\"requiredWorkerCount\":1,\"estimatedDurationMinutes\":120,\"districtIds\":[\"$DIST\"]}" | j id)
eq "Service created" "$([ -n "$SVC" ] && echo yes)" "yes"

# On the roster, but holding nothing yet.
want_ok "Worker invited to the roster" "$(post_ /business/workers/invite "$BT" "{\"workerIdentifier\":\"wc_w1$S@zuno.local\"}")" ""
INV=$(get_ /worker/invitations "$W1" | j id)
want_ok "Worker accepts the invitation" "$(post_ /worker/invitations/$INV/respond "$W1" '{"accept":true}')" ""

mk() { post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$1\",\"addressLine1\":\"14 Nila Nagar\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"latitude\":10.5276,\"longitude\":76.2144,\"country\":\"India\"}" | j id; }
assign() { sql "insert into booking_worker_assignments (id, booking_id, worker_profile_id, assignment_status, responded_at, created_date, is_deleted, status) values (gen_random_uuid(),'$1','$WP',2,now(),now(),false,1) returning 1" | head -1; }

echo
echo "==== 1. NOTHING ON: FREE, AND AN EMPTY SCHEDULE ===="
agree "Free badge, no dates behind it" "Active" "0"

echo
echo "==== 2. ONE ORDER: BOOKED, AND ONE DATE ===="
# Inside the customer booking horizon (platform setting, 90 days by default), so the dates are relative.
DAY1=$(date -u -d "+30 days" +%Y-%m-%d)
DAY5=$(date -u -d "+34 days" +%Y-%m-%d)
D1=${DAY1}T09:00:00Z
B1=$(mk $D1); post_ /business/bookings/$B1/confirm "$BT" >/dev/null
eq "Assignment written" "$(assign $B1)" "1"
agree "Booked badge, one date behind it" "Booked" "1"
R=$(sched)
eq "The window is a real one"  "$(echo "$R" | grep -o '"endsAt":"[^"]*"' | head -1 | cut -d'"' -f4 | cut -c12-16)" "11:00"

echo
echo "==== 3. SEVERAL DATES, AND SEVERAL JOBS ON ONE DATE ===="
B2=$(mk ${DAY1}T14:00:00Z); post_ /business/bookings/$B2/confirm "$BT" >/dev/null   # same day, later
B3=$(mk ${DAY5}T08:00:00Z); post_ /business/bookings/$B3/confirm "$BT" >/dev/null   # another day
eq "Two more assignments written" "$(assign $B2)$(assign $B3)" "11"
agree "Still one badge, now three dates" "Booked" "3"
R=$(sched)
eq "Two of them fall on the first day"  "$(echo "$R" | grep -o "\"startsAt\":\"$DAY1" | wc -l | tr -d ' ')" "2"
eq "Soonest first"              "$(echo "$R" | grep -o '"startsAt":"[^"]*"' | head -1 | cut -d'"' -f4 | cut -c1-16)" "${DAY1}T09:00"

echo
echo "==== 4. TWO ORDERS AT THE IDENTICAL MINUTE STAY TWO ENTRIES ===="
# The shape the old distinct-timestamp query threw away. A double-booking is the single most
# important thing this screen can show.
BSAME=$(mk $D1); post_ /business/bookings/$BSAME/confirm "$BT" >/dev/null
eq "A clashing assignment written" "$(assign $BSAME)" "1"
agree "Four dates now, not three" "Booked" "4"
eq "Two start at exactly 09:00"    "$(sched | grep -o "\"startsAt\":\"${DAY1}T09:00" | wc -l | tr -d ' ')" "2"

echo
echo "==== 5. THE SCHEDULE NAMES TIMES, NEVER THE WORK ===="
R=$(sched)
for FIELD in title name service businessName isMine source; do
  if echo "$R" | grep -q "\"$FIELD\""; then
    bad "No \"$FIELD\" field on a schedule entry" "LEAKED"
  else
    ok "No \"$FIELD\" field on a schedule entry" "absent"
  fi
done
if echo "$R" | grep -q 'Catering'; then bad "The service name never appears" "LEAKED"; else ok "The service name never appears" "times only"; fi

echo
echo "==== 6. THE BUG: CANCELLED WORK MUST RELEASE THE BADGE TOO ===="
# Cancelling every order should take the badge back to free *and* empty the schedule. The old
# availability query had no cancelled filter, so the badge stuck on "Booked" for ever while the
# schedule showed nothing.
for B in $B1 $B2 $B3 $BSAME; do post_ /customer/bookings/$B/cancel "$CT" '{"cancellationReason":"Changed plans"}' >/dev/null; done
agree "Free again, and the schedule is empty" "Active" "0"

echo
echo "==== 7. THE OTHER HALF: A HIRING POST MUST SET THE BADGE ===="
# The old availability query looked at bookings only, so a worker hired through a post read as
# free while their schedule listed the job.
P=$(post_ /business/hiring-posts "$BT" "{\"title\":\"Depot shift\",\"eventDate\":\"2027-04-20T10:00:00Z\",\"durationMinutes\":180,\"workersNeeded\":1,\"salaryAmount\":700,\"salaryUnit\":\"PerEvent\",\"location\":\"Depot\"}" | j id)
want_ok "Worker invited to a hiring post" "$(post_ /business/hiring-posts/$P/invite "$BT" "{\"workerIdentifier\":\"wc_w1$S@zuno.local\"}")" ""
agree "An unanswered offer holds nobody" "Active" "0"

PA=$(sql "select a.id from hiring_post_applications a where a.hiring_post_id='$P' and a.worker_profile_id='$WP' and a.is_deleted=false limit 1")
want_ok "Worker accepts it" "$(post_ /worker/hiring-posts/applications/$PA/respond "$W1" '{"accept":true}')" ""
agree "Now booked by the post, with its date" "Booked" "1"
eq "Dated to the post's own event" "$(sched | grep -o '"startsAt":"[^"]*"' | head -1 | cut -d'"' -f4 | cut -c1-10)" "2027-04-20"
eq "...and 3 hours long"           "$(sched | grep -o '"endsAt":"[^"]*"' | head -1 | cut -d'"' -f4 | cut -c12-16)" "13:00"

echo
echo "==== 8. THE DASHBOARD ROSTER AGREES WITH BOTH ===="
D=$(get_ /business/dashboard "$BT")
eq "Dashboard reports the same badge" "$(echo "$D" | grep -o '"availabilityStatus":"[^"]*"' | head -1 | cut -d'"' -f4)" "Booked"
eq "...dated the same way"            "$(echo "$D" | grep -o '"busyOn":"[^"]*"' | head -1 | cut -d'"' -f4 | cut -c1-10)" "2027-04-20"
if echo "$D" | grep -q '"busyWith"'; then bad "...and names no job" "busyWith is back"; else ok "...and names no job" "date only"; fi

echo
echo "================ $PASS passed, $FAIL failed ================"
[ "$FAIL" -eq 0 ]
