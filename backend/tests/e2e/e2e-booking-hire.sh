#!/usr/bin/env bash
# End-to-end: hiring a crew for a customer booking.
API=http://localhost:5056/api/v1
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-90; }

ok()  { PASS=$((PASS+1)); printf 'PASS  %-50s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-50s %s\n' "$1" "$2"; }
want_ok() { if echo "$2" | grep -q '"success":true'; then ok "$1" "$3"; else bad "$1" "$(echo "$2" | msg)"; fi; }
want_no() { if echo "$2" | grep -q '"success":false'; then ok "$1" "$(echo "$2" | msg)"; else bad "$1" "allowed but should have been refused"; fi; }
eq()      { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }

# Registration is rate limited to 5/min per IP. A silently empty token here does not fail the
# run — it makes later checks pass or fail for reasons that have nothing to do with the code, so
# this waits the window out and tries once more rather than handing back nothing.
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

echo "================ SETUP ================"
BT=$(reg Boss "bh_b$S@zuno.local" BusinessOwner | j accessToken)
CT=$(reg Cust "bh_c$S@zuno.local" Customer | j accessToken)
W1=$(reg Wone "bh_w1$S@zuno.local" Worker | j accessToken)
W2=$(reg Wtwo "bh_w2$S@zuno.local" Worker | j accessToken)
W3=$(reg Wthree "bh_w3$S@zuno.local" Worker | j accessToken)
if [ -z "$BT" ] || [ -z "$CT" ] || [ -z "$W1" ]; then echo "registration failed (rate limit?)"; exit 1; fi
ok "Registered business, customer, 3 workers" "bh_b$S@zuno.local"

BIZ=$(sql "select b.id from business_owner_profiles b join users u on u.id=b.user_id where u.email='bh_b$S@zuno.local'")
sql "update business_owner_profiles set verification_status=1, verified_at=now() where id='$BIZ'" >/dev/null
DIST=$(sql "select id from districts limit 1")
CAT=a1111111-0000-0000-0000-000000000003

SVC=$(post_ /business/services "$BT" "{\"serviceCategoryId\":\"$CAT\",\"name\":\"Catering\",\"priceType\":\"Fixed\",\"price\":5000,\"requiredWorkerCount\":1,\"districtIds\":[\"$DIST\"]}" | j id)
eq "Service created" "$([ -n "$SVC" ] && echo yes)" "yes"

# Booking, placed by the customer against that service.
WHEN=$(date -u -d '+10 days 10:00' +%Y-%m-%dT%H:%M:%SZ)
BK=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$WHEN\",\"requiredWorkerCount\":5,\"addressLine1\":\"14 Nila Nagar\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"latitude\":10.5276,\"longitude\":76.2144,\"country\":\"India\"}" | j id)
eq "Customer booking created" "$([ -n "$BK" ] && echo yes)" "yes"
want_ok "Business confirms the booking" "$(post_ /business/bookings/$BK/confirm "$BT")" ""

echo
echo "==== 1. CREW SIZE: 2 came from offline, so post for 3 ===="
want_ok "Crew size set to 3" "$(post_ /business/bookings/$BK/crew-size "$BT" '{"requiredWorkerCount":3}')" "was 5"

echo
echo "==== 2. HIRING POST LINKED TO THE BOOKING ===="
EV=$(date -u -d '+10 days 10:00' +%Y-%m-%dT%H:%M:%SZ)
R=$(post_ /business/hiring-posts "$BT" "{\"bookingId\":\"$BK\",\"title\":\"Catering\",\"eventDate\":\"$EV\",\"durationMinutes\":240,\"workersNeeded\":3,\"salaryAmount\":700,\"salaryUnit\":\"PerEvent\",\"serviceSubCategoryId\":\"a2222222-0000-0000-0003-000000000002\",\"location\":\"14 Nila Nagar\"}")
POST=$(echo "$R" | j id)
want_ok "Post created against the booking" "$R" "3 workers @ 700"
eq "Post stores the booking id" "$(sql "select booking_id from hiring_posts where id='$POST'")" "$BK"
REF=$(get_ /business/hiring-posts "$BT" | grep -o '"bookingReference":"[^"]*"' | head -1 | cut -d'"' -f4)
if echo "$REF" | grep -qE '^#[0-9A-F]{8} · Catering'; then ok "bookingReference names the order" "$REF"; else bad "bookingReference names the order" "got '$REF'"; fi

# Another business must not be able to hire against this booking. Registration is rate limited
# to 5/min per IP and this script has already spent its budget, so wait the window out rather
# than silently testing with an empty token — which is exactly how this check passed a run it
# should have failed.
sleep 70
B2=$(reg Other "bh_o$S@zuno.local" BusinessOwner | j accessToken)
if [ -z "$B2" ]; then bad "Refused: booking belongs to another business" "still rate limited, not tested"; else
want_no "Refused: booking belongs to another business" \
  "$(post_ /business/hiring-posts "$B2" "{\"bookingId\":\"$BK\",\"title\":\"X\",\"eventDate\":\"$EV\",\"durationMinutes\":120,\"workersNeeded\":1,\"salaryAmount\":100,\"salaryUnit\":\"PerEvent\",\"serviceSubCategoryId\":\"a2222222-0000-0000-0003-000000000002\"}")"
fi

echo
echo "==== 3. WORKER 1 ACCEPTS -> AUTO-ASSIGNED TO THE BOOKING ===="
want_ok "Invite worker 1" "$(post_ /business/hiring-posts/$POST/invite "$BT" "{\"workerIdentifier\":\"bh_w1$S@zuno.local\"}")" ""
A1=$(sql "select a.id from hiring_post_applications a join worker_profiles w on w.id=a.worker_profile_id join users u on u.id=w.user_id where a.hiring_post_id='$POST' and u.email='bh_w1$S@zuno.local'")
ACC=$(post_ /worker/hiring-posts/applications/$A1/respond "$W1" '{"accept":true}')
want_ok "Worker 1 accepts (clash check must NOT veto)" "$ACC" "the trap"
eq "Booking assignment created" \
  "$(sql "select count(*) from booking_worker_assignments a join worker_profiles w on w.id=a.worker_profile_id join users u on u.id=w.user_id where a.booking_id='$BK' and u.email='bh_w1$S@zuno.local' and a.is_deleted=false")" "1"
eq "...with status Accepted (2), not Assigned" \
  "$(sql "select a.assignment_status from booking_worker_assignments a join worker_profiles w on w.id=a.worker_profile_id join users u on u.id=w.user_id where a.booking_id='$BK' and u.email='bh_w1$S@zuno.local'")" "2"
# The order's own status must survive staffing — this is the whole point of splitting the tracks.
eq "Order still reads Confirmed (6) after hiring" "$(sql "select booking_status from bookings where id='$BK'")" "6"
eq "Crew track says PartStaffed" "$(get_ /business/bookings "$BT" | tr '{' '\n' | grep "\"id\":\"$BK\"" | grep -o '"crewStatus":"[^"]*"' | cut -d'"' -f4)" "PartStaffed"

echo
echo "==== 4. WORKER 2 ACCEPTS -> 2 of 3 ===="
want_ok "Invite worker 2" "$(post_ /business/hiring-posts/$POST/invite "$BT" "{\"workerIdentifier\":\"bh_w2$S@zuno.local\"}")" ""
A2=$(sql "select a.id from hiring_post_applications a join worker_profiles w on w.id=a.worker_profile_id join users u on u.id=w.user_id where a.hiring_post_id='$POST' and u.email='bh_w2$S@zuno.local'")
want_ok "Worker 2 accepts" "$(post_ /worker/hiring-posts/applications/$A2/respond "$W2" '{"accept":true}')" ""
eq "Booking crew now 2" "$(sql "select count(*) from booking_worker_assignments where booking_id='$BK' and assignment_status in (1,2) and is_deleted=false")" "2"

echo
echo "==== 5. NO HEADCOUNT CAP ON AN ORDER ===="
# An order carries no crew requirement — the customer booked a service, not a number of people.
# A third hire must land even though the service definition says fewer.
sql "update bookings set required_worker_count=2 where id='$BK'" >/dev/null
ok "Service definition says 2" "the third hire must still land"
want_ok "Invite worker 3" "$(post_ /business/hiring-posts/$POST/invite "$BT" "{\"workerIdentifier\":\"bh_w3$S@zuno.local\"}")" ""
A3=$(sql "select a.id from hiring_post_applications a join worker_profiles w on w.id=a.worker_profile_id join users u on u.id=w.user_id where a.hiring_post_id='$POST' and u.email='bh_w3$S@zuno.local'")
want_ok "Worker 3 accepts" "$(post_ /worker/hiring-posts/applications/$A3/respond "$W3" '{"accept":true}')" ""
eq "...and IS on the order, not silently dropped" "$(sql "select count(*) from booking_worker_assignments a join worker_profiles w on w.id=a.worker_profile_id join users u on u.id=w.user_id where a.booking_id='$BK' and u.email='bh_w3$S@zuno.local' and a.is_deleted=false")" "1"
eq "Worker 3 is hired on the post" "$(sql "select application_status from hiring_post_applications where id='$A3'")" "4"

echo
echo "==== 6. CANCELLING THE BOOKING CLOSES THE OPEN POST ===="
BK2=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$(date -u -d '+20 days 10:00' +%Y-%m-%dT%H:%M:%SZ)\",\"requiredWorkerCount\":2,\"addressLine1\":\"9 Market Rd\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"latitude\":10.5276,\"longitude\":76.2144,\"country\":\"India\"}" | j id)
post_ /business/bookings/$BK2/confirm "$BT" >/dev/null
P2=$(post_ /business/hiring-posts "$BT" "{\"bookingId\":\"$BK2\",\"title\":\"Catering\",\"eventDate\":\"$(date -u -d '+20 days 10:00' +%Y-%m-%dT%H:%M:%SZ)\",\"durationMinutes\":180,\"workersNeeded\":2,\"salaryAmount\":600,\"salaryUnit\":\"PerEvent\",\"serviceSubCategoryId\":\"a2222222-0000-0000-0003-000000000002\"}" | j id)
eq "Second post is Open (1)" "$(sql "select hiring_post_status from hiring_posts where id='$P2'")" "1"
# Cancelled by the customer: once a business has accepted an order, calling it off is theirs.
want_ok "Customer cancels the confirmed order" "$(post_ /customer/bookings/$BK2/cancel "$CT" '{"reason":"Plans changed"}')" ""
eq "Linked post closed (2)" "$(sql "select hiring_post_status from hiring_posts where id='$P2'")" "2"
want_no "Refused: cannot hire for a cancelled booking" \
  "$(post_ /business/hiring-posts "$BT" "{\"bookingId\":\"$BK2\",\"title\":\"Catering\",\"eventDate\":\"$EV\",\"durationMinutes\":120,\"workersNeeded\":1,\"salaryAmount\":100,\"salaryUnit\":\"PerEvent\",\"serviceSubCategoryId\":\"a2222222-0000-0000-0003-000000000002\"}")"

echo
echo "==== 5b. ORDER TRACK AND CREW TRACK ARE SEPARATE ===="
eq "Crew is full, so crew track says FullyStaffed" \
  "$(get_ /business/bookings "$BT" | tr '{' '\n' | grep "\"id\":\"$BK\"" | grep -o '"crewStatus":"[^"]*"' | cut -d'"' -f4)" "FullyStaffed"
eq "...while the order is still only Confirmed (6)" "$(sql "select booking_status from bookings where id='$BK'")" "6"
# Work cannot begin before the day it was booked for, so bring the day forward first. The rule
# itself is covered properly in e2e-order-lifecycle.sh.
want_no "Refused: the event is still days away" "$(post_ /business/bookings/$BK/start "$BT")"
sql "update bookings set scheduled_date=now() - interval '1 hour' where id='$BK'" >/dev/null
want_ok "Start work moves the ORDER to in progress" "$(post_ /business/bookings/$BK/start "$BT")" ""
eq "Order now InProgress (3)" "$(sql "select booking_status from bookings where id='$BK'")" "3"
eq "...with a real start time recorded" "$(sql "select (work_started_at is not null) from bookings where id='$BK'")" "t"
want_no "Refused: cannot start twice" "$(post_ /business/bookings/$BK/start "$BT")"

BK3=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$(date -u -d '+25 days 10:00' +%Y-%m-%dT%H:%M:%SZ)\",\"addressLine1\":\"2 Temple St\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"latitude\":10.5276,\"longitude\":76.2144,\"country\":\"India\"}" | j id)
want_no "Refused: cannot start an unconfirmed order" "$(post_ /business/bookings/$BK3/start "$BT")"
post_ /business/bookings/$BK3/confirm "$BT" >/dev/null
want_no "Refused: cannot start with nobody hired" "$(post_ /business/bookings/$BK3/start "$BT")"

echo
echo "==== 5d. ALL THREE HIRING CHANNELS FEED ONE COUNT ===="
# A fresh order needing 3: one from a post application, one from an invite, one added by hand.
BKC=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$(date -u -d '+40 days 09:00' +%Y-%m-%dT%H:%M:%SZ)\",\"addressLine1\":\"7 Mill Rd\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"latitude\":10.5276,\"longitude\":76.2144,\"country\":\"India\"}" | j id)
post_ /business/bookings/$BKC/confirm "$BT" >/dev/null
sql "update bookings set required_worker_count=3 where id='$BKC'" >/dev/null
EVC=$(date -u -d '+40 days 09:00' +%Y-%m-%dT%H:%M:%SZ)
PC=$(post_ /business/hiring-posts "$BT" "{\"bookingId\":\"$BKC\",\"title\":\"Catering\",\"eventDate\":\"$EVC\",\"durationMinutes\":180,\"workersNeeded\":3,\"salaryAmount\":800,\"salaryUnit\":\"PerEvent\",\"serviceSubCategoryId\":\"a2222222-0000-0000-0003-000000000002\"}" | j id)
eq "Start at 0 hired" "$(sql "select count(*) from booking_worker_assignments where booking_id='$BKC' and assignment_status in (1,2) and is_deleted=false")" "0"

# Channel 1 — worker applies to the open post, business confirms, worker accepts.
W4=$(reg Wfour "bh_w4$S@zuno.local" Worker | j accessToken)
post_ /worker/hiring-posts/$PC/apply "$W4" >/dev/null
A4=$(sql "select a.id from hiring_post_applications a join worker_profiles w on w.id=a.worker_profile_id join users u on u.id=w.user_id where a.hiring_post_id='$PC' and u.email='bh_w4$S@zuno.local'")
post_ /business/hiring-posts/applications/$A4/confirm "$BT" >/dev/null
post_ /worker/hiring-posts/applications/$A4/respond "$W4" '{"accept":true}' >/dev/null
eq "Channel 1 (applied to post) -> 1 hired" "$(sql "select count(*) from booking_worker_assignments where booking_id='$BKC' and assignment_status in (1,2) and is_deleted=false")" "1"

# Channel 2 — business invites a specific worker to that post.
W5=$(reg Wfive "bh_w5$S@zuno.local" Worker | j accessToken)
post_ /business/hiring-posts/$PC/invite "$BT" "{\"workerIdentifier\":\"bh_w5$S@zuno.local\"}" >/dev/null
A5=$(sql "select a.id from hiring_post_applications a join worker_profiles w on w.id=a.worker_profile_id join users u on u.id=w.user_id where a.hiring_post_id='$PC' and u.email='bh_w5$S@zuno.local'")
post_ /worker/hiring-posts/applications/$A5/respond "$W5" '{"accept":true}' >/dev/null
eq "Channel 2 (invited to post) -> 2 hired" "$(sql "select count(*) from booking_worker_assignments where booking_id='$BKC' and assignment_status in (1,2) and is_deleted=false")" "2"

# Channel 3 — added by hand from the roster (worker 1 is already on the roster).
W1ID=$(sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='bh_w1$S@zuno.local'")
# Worker 1 is still on the order started above, and a worker mid-job takes nothing else until
# somebody closes it. Close it — which is what a business would do — and they are free again.
# The rule itself is covered in e2e-order-lifecycle.sh.
want_no "Refused while worker 1 is still mid-job" "$(post_ /business/bookings/$BKC/assign-worker "$BT" "{\"workerProfileId\":\"$W1ID\"}")"
want_ok "That job is marked completed" "$(post_ /business/bookings/$BK/complete "$BT")" ""
want_ok "Channel 3 (added by hand)" "$(post_ /business/bookings/$BKC/assign-worker "$BT" "{\"workerProfileId\":\"$W1ID\"}")" ""
eq "...-> 3 hired, the job is full" "$(sql "select count(*) from booking_worker_assignments where booking_id='$BKC' and assignment_status in (1,2) and is_deleted=false")" "3"
eq "Crew track reads FullyStaffed" "$(get_ /business/bookings "$BT" | tr '{' '\n' | grep "\"id\":\"$BKC\"" | grep -o '"crewStatus":"[^"]*"' | cut -d'"' -f4)" "FullyStaffed"
eq "activeCrewCount is 3 of 3" "$(get_ /business/bookings "$BT" | tr '{' '\n' | grep "\"id\":\"$BKC\"" | grep -o '"activeCrewCount":[0-9]*' | cut -d: -f2)" "3"

echo
echo "==== 5c. THE CUSTOMER IS NOT TOLD ABOUT THE CREW ===="
CUSTVIEW=$(get_ /customer/bookings "$CT")
eq "No worker names or phones reach the customer" "$(echo "$CUSTVIEW" | grep -o 'workerPhone' | wc -l | tr -d ' ')" "0"
eq "Crew list is empty for the customer" "$(echo "$CUSTVIEW" | grep -o '"assignedWorkers":\[\]' | wc -l | tr -d ' ')" "$(echo "$CUSTVIEW" | grep -o '"assignedWorkers"' | wc -l | tr -d ' ')"
eq "Crew status withheld from the customer" "$(echo "$CUSTVIEW" | grep -o '"crewStatus":"[^"]*"' | cut -d'"' -f4 | sort -u | tr -d '\n')" ""
# ...but the business still gets all of it.
BIZVIEW=$(get_ /business/bookings "$BT")
if echo "$BIZVIEW" | grep -q 'workerPhone'; then ok "Business still receives the crew" "names and phones present"; else bad "Business still receives the crew" "crew missing for the business too"; fi

echo
echo "==== 6c. A BUSINESS DECLINES BEFORE ACCEPTING, NEVER AFTER ===="
BKD=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$(date -u -d '+50 days 09:00' +%Y-%m-%dT%H:%M:%SZ)\",\"addressLine1\":\"1 High St\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"latitude\":10.5276,\"longitude\":76.2144,\"country\":\"India\"}" | j id)
want_ok "Business declines a pending order" "$(post_ /business/bookings/$BKD/cancel "$BT" '{"reason":"Fully booked that day"}')" ""

BKE=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$(date -u -d '+55 days 09:00' +%Y-%m-%dT%H:%M:%SZ)\",\"addressLine1\":\"3 High St\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"latitude\":10.5276,\"longitude\":76.2144,\"country\":\"India\"}" | j id)
post_ /business/bookings/$BKE/confirm "$BT" >/dev/null
want_no "Refused: business cannot back out once accepted" "$(post_ /business/bookings/$BKE/cancel "$BT" '{"reason":"changed my mind"}')"
eq "...and the order is untouched, still Confirmed (6)" "$(sql "select booking_status from bookings where id='$BKE'")" "6"
# The customer keeps the right to call off their own order.
want_ok "Customer can still cancel that confirmed order" "$(post_ /customer/bookings/$BKE/cancel "$CT" '{"reason":"Plans changed"}')" ""
eq "...now Cancelled (5)" "$(sql "select booking_status from bookings where id='$BKE'")" "5"

echo
echo "==== 6d. A POST INHERITS THE ORDER'S PICTURE AND KIND OF WORK ===="
# A package with its own photo and its own kind of work, plus a different photo on the service,
# so we can tell which one the post actually took.
KITCHEN=a2222222-0000-0000-0003-000000000002
VAR=$(post_ /business/services/$SVC/variants "$BT" "{\"name\":\"Kitchen deep clean\",\"serviceSubCategoryId\":\"$KITCHEN\",\"priceType\":\"Fixed\",\"price\":900}" \
  | tr '{' '\n' | grep '"name":"Kitchen deep clean"' | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
# ck_business_service_media_owner: a row belongs to a service OR a variant, never both.
sql "insert into business_service_media (id, business_service_id, business_service_variant_id, media_type, url, sort_order, created_date, is_deleted, status)
     values (gen_random_uuid(), null, '$VAR', 1, '/uploads/test/variant.jpg', 0, now(), false, 1),
            (gen_random_uuid(), '$SVC', null, 1, '/uploads/test/service.jpg', 0, now(), false, 1)" >/dev/null
eq "Package has its own photo" "$(sql "select url from business_service_media where business_service_variant_id='$VAR'")" "/uploads/test/variant.jpg"

BKI=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"businessServiceVariantId\":\"$VAR\",\"scheduledDate\":\"$(date -u -d '+60 days 09:00' +%Y-%m-%dT%H:%M:%SZ)\",\"addressLine1\":\"5 Park Rd\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"latitude\":10.5276,\"longitude\":76.2144,\"country\":\"India\"}" | j id)
post_ /business/bookings/$BKI/confirm "$BT" >/dev/null
eq "Order reports its kind of work" "$(get_ /business/bookings "$BT" | tr '{' '\n' | grep "\"id\":\"$BKI\"" | grep -o '"serviceSubCategoryName":"[^"]*"' | cut -d'"' -f4)" "Kitchen cleaning"

# Note: no serviceSubCategoryId sent — the post must take it from the order by itself.
PI=$(post_ /business/hiring-posts "$BT" "{\"bookingId\":\"$BKI\",\"title\":\"Catering\",\"eventDate\":\"$(date -u -d '+60 days 09:00' +%Y-%m-%dT%H:%M:%SZ)\",\"durationMinutes\":120,\"workersNeeded\":1,\"salaryAmount\":500,\"salaryUnit\":\"PerEvent\"}" | j id)
eq "Post took the PACKAGE photo, not the service one" "$(sql "select image_url from hiring_posts where id='$PI'")" "/uploads/test/variant.jpg"
eq "Post inherited the order's kind of work" "$(sql "select sc.name from hiring_posts p join service_sub_categories sc on sc.id=p.service_sub_category_id where p.id='$PI'")" "Kitchen cleaning"

echo
echo "==== 6b. ORDER CODES ARE DISTINCT ===="
R1=$(get_ /customer/bookings "$CT" | grep -o '"reference":"[^"]*"' | cut -d'"' -f4 | sort -u | wc -l)
RN=$(get_ /customer/bookings "$CT" | grep -o '"reference":"[^"]*"' | wc -l)
eq "Every order has its own code" "$R1" "$RN"

echo
echo "==== 7. REGRESSION: STANDALONE POSTS STILL WORK ===="
R3=$(post_ /business/hiring-posts "$BT" "{\"title\":\"Catering\",\"eventDate\":\"$(date -u -d '+30 days 09:00' +%Y-%m-%dT%H:%M:%SZ)\",\"durationMinutes\":120,\"workersNeeded\":1,\"salaryAmount\":500,\"salaryUnit\":\"PerEvent\",\"serviceSubCategoryId\":\"a2222222-0000-0000-0003-000000000002\"}")
P3=$(echo "$R3" | j id)
want_ok "Standalone post (no bookingId) created" "$R3" ""
eq "...with a null booking_id" "$(sql "select coalesce(booking_id::text,'null') from hiring_posts where id='$P3'")" "null"

echo
echo "================ $PASS passed, $FAIL failed ================"
[ "$FAIL" -eq 0 ]
