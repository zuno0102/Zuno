#!/usr/bin/env bash
# End-to-end: the exact job location, from the customer's pin to the worker's map.
#
#   customer pins the job  ->  business sees the pin  ->  crew post inherits it (district too)
#   ->  workers nearby find it with a distance, workers far away do not  ->  assigned worker sees it
#   plus: a post with no order is placed from the business's own pin, and edits keep or move it.
API=${API:-http://localhost:5056/api/v1}
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
n()   { grep -o "\"$1\":[-0-9.]*" | head -1 | cut -d: -f2; }
msg() { tr ',' '\n' | grep -E '"(message|Latitude|Longitude)"' | head -2 | tr '\n' ' ' | cut -c1-110; }

ok()  { PASS=$((PASS+1)); printf 'PASS  %-58s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-58s %s\n' "$1" "$2"; }
want_ok() { if echo "$2" | grep -q '"success":true'; then ok "$1" "$3"; else bad "$1" "$(echo "$2" | msg)"; fi; }
want_no() { if echo "$2" | grep -q '"success":false'; then ok "$1" "$(echo "$2" | msg)"; else bad "$1" "allowed but should have been refused"; fi; }
eq()      { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }
# Numbers compared to 4 decimals: the database keeps 6, JSON may print fewer.
near()    { if awk -v a="$2" -v b="$3" 'BEGIN{d=a-b; if(d<0)d=-d; exit !(a!="" && d<0.0001)}'; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }

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
put_()  { curl -s -X PUT "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$3"; }
get_()  { curl -s "$API$1" -H "Authorization: Bearer $2"; }

# The job: 12, Church Street, Marthandam (Kanniyakumari district, Tamil Nadu).
JOB_LAT=8.312345; JOB_LON=77.220111

echo "================ SETUP ================"
BT=$(reg Boss "jl_b$S@zuno.local" BusinessOwner | j accessToken)
CT=$(reg Cust "jl_c$S@zuno.local" Customer | j accessToken)
WT=$(reg Wkr "jl_w$S@zuno.local" Worker | j accessToken)
if [ -z "$BT" ] || [ -z "$CT" ] || [ -z "$WT" ]; then echo "registration failed (rate limit?)"; exit 1; fi
ok "Registered business, customer, worker" "jl_b$S@zuno.local"

BIZ=$(sql "select b.id from business_owner_profiles b join users u on u.id=b.user_id where u.email='jl_b$S@zuno.local'")
sql "update business_owner_profiles set verification_status=1, verified_at=now() where id='$BIZ'" >/dev/null
KK=$(sql "select id from districts where name ilike 'kan%kumari' limit 1")
eq "Kanniyakumari district is seeded with a centre" "$([ -n "$KK" ] && echo yes)" "yes"
CAT=a1111111-0000-0000-0000-000000000003
SVC=$(post_ /business/services "$BT" "{\"serviceCategoryId\":\"$CAT\",\"name\":\"Wedding catering\",\"priceType\":\"Fixed\",\"price\":25000,\"requiredWorkerCount\":1,\"districtIds\":[\"$KK\"]}" | j id)
eq "Service created" "$([ -n "$SVC" ] && echo yes)" "yes"
WHEN=$(date -u -d '+10 days 10:00' +%Y-%m-%dT%H:%M:%SZ)
ADDR="\"addressLine1\":\"12, Church Street\",\"addressLine2\":\"Opposite Nila Nagar Church\",\"city\":\"Marthandam\",\"state\":\"Tamil Nadu\",\"postalCode\":\"629165\",\"country\":\"India\""

echo
echo "==== 1. CUSTOMER MUST PIN THE JOB ===="
R=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$WHEN\",$ADDR}")
want_no "Refused: booking with no map pin" "$R"
if echo "$R" | grep -q 'Pin the job location on the map'; then ok "...with a message the customer understands" ""; else bad "...with a message the customer understands" "$(echo "$R" | cut -c1-120)"; fi
want_no "Refused: latitude off the globe" "$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$WHEN\",$ADDR,\"latitude\":95,\"longitude\":77.2}")"
want_no "Refused: only one coordinate" "$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$WHEN\",$ADDR,\"latitude\":8.3}")"

R=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$WHEN\",$ADDR,\"latitude\":$JOB_LAT,\"longitude\":$JOB_LON}")
want_ok "Booking with a pin is accepted" "$R"
BK=$(echo "$R" | j id)
near "Customer's copy carries the latitude" "$(echo "$R" | n latitude)" "$JOB_LAT"
eq "Customer's copy carries the landmark line" "$(echo "$R" | j addressLine2)" "Opposite Nila Nagar Church"
near "Stored in the address row (latitude)" "$(sql "select a.latitude from bookings b join addresses a on a.id=b.address_id where b.id='$BK'")" "$JOB_LAT"
near "Stored in the address row (longitude)" "$(sql "select a.longitude from bookings b join addresses a on a.id=b.address_id where b.id='$BK'")" "$JOB_LON"

echo
echo "==== 2. BUSINESS SEES THE EXACT PIN ===="
R=$(get_ /business/bookings/$BK "$BT")
near "Business booking detail: latitude" "$(echo "$R" | n latitude)" "$JOB_LAT"
near "Business booking detail: longitude" "$(echo "$R" | n longitude)" "$JOB_LON"
eq "Business booking detail: landmark" "$(echo "$R" | j addressLine2)" "Opposite Nila Nagar Church"
near "Business booking list carries the pin too" "$(get_ /business/bookings "$BT" | tr '{' '\n' | grep -A40 "\"id\":\"$BK\"" | n latitude)" "$JOB_LAT"
want_ok "Business confirms the booking" "$(post_ /business/bookings/$BK/confirm "$BT")" ""

echo
echo "==== 3. CREW POST FROM THE ORDER INHERITS THE PIN ===="
EV=$WHEN
# The business sends different coordinates on purpose: the order's pin must win.
R=$(post_ /business/hiring-posts "$BT" "{\"bookingId\":\"$BK\",\"title\":\"Catering crew\",\"eventDate\":\"$EV\",\"durationMinutes\":240,\"workersNeeded\":2,\"salaryAmount\":900,\"salaryUnit\":\"PerEvent\",\"latitude\":10.0,\"longitude\":76.0}")
want_ok "Post raised from the order" "$R"
POST=$(echo "$R" | j id)
eq "Precision is Pinned" "$(echo "$R" | j locationPrecision)" "Pinned"
near "Post latitude = the order's pin" "$(sql "select latitude from hiring_posts where id='$POST'")" "$JOB_LAT"
near "Post longitude = the order's pin" "$(sql "select longitude from hiring_posts where id='$POST'")" "$JOB_LON"
eq "District set from the pin: Kanniyakumari" "$(sql "select district_id from hiring_posts where id='$POST'")" "$KK"
eq "Location text filled from the order's address" "$(sql "select location from hiring_posts where id='$POST'")" "12, Church Street, Opposite Nila Nagar Church, Marthandam, Tamil Nadu"

echo
echo "==== 4. WORKERS NEARBY FIND IT, FAR AWAY DO NOT (existing feed, unchanged) ===="
# Kuzhithurai, about 2.8 km from the job.
FEED=$(get_ "/worker/hiring-posts?latitude=8.3170&longitude=77.1950&radiusKm=5" "$WT")
ROW=$(echo "$FEED" | tr '{' '\n' | grep -A60 "\"id\":\"$POST\"" | head -60)
eq "Post appears for a worker 2.8 km away" "$([ -n "$ROW" ] && echo yes)" "yes"
D=$(echo "$FEED" | grep -o "\"id\":\"$POST\".*" | n distanceKm)
if awk -v d="$D" 'BEGIN{exit !(d!="" && d>1.5 && d<4.5)}'; then ok "...with a real distance" "$D km"; else bad "...with a real distance" "got '$D'"; fi
FAR=$(get_ "/worker/hiring-posts?latitude=13.0827&longitude=80.2707&radiusKm=5" "$WT")
eq "Hidden from a worker in Chennai at 5 km" "$(echo "$FAR" | grep -c "\"id\":\"$POST\"")" "0"
eq "District filter matches it too" "$(get_ "/worker/hiring-posts?districtIds=$KK" "$WT" | grep -c "\"id\":\"$POST\"")" "1"

echo
echo "==== 5. THE ASSIGNED WORKER SEES THE PIN ON THE JOB ===="
want_ok "Business invites the worker" "$(post_ /business/hiring-posts/$POST/invite "$BT" "{\"workerIdentifier\":\"jl_w$S@zuno.local\"}")" ""
APP=$(sql "select a.id from hiring_post_applications a join worker_profiles w on w.id=a.worker_profile_id join users u on u.id=w.user_id where a.hiring_post_id='$POST' and u.email='jl_w$S@zuno.local'")
want_ok "Worker accepts" "$(post_ /worker/hiring-posts/applications/$APP/respond "$WT" '{"accept":true}')" ""
R=$(get_ /worker/jobs/$BK "$WT")
near "Worker job detail: latitude" "$(echo "$R" | n latitude)" "$JOB_LAT"
near "Worker job detail: longitude" "$(echo "$R" | n longitude)" "$JOB_LON"
eq "Worker job detail: landmark" "$(echo "$R" | j addressLine2)" "Opposite Nila Nagar Church"

echo
echo "==== 6. POST WITH NO ORDER: THE BUSINESS'S OWN PIN ===="
R=$(post_ /business/hiring-posts "$BT" "{\"title\":\"Stage helpers\",\"eventDate\":\"$EV\",\"durationMinutes\":180,\"workersNeeded\":1,\"salaryAmount\":700,\"salaryUnit\":\"PerEvent\",\"location\":\"Near St. Mary's Church, Kuzhithurai\",\"latitude\":8.3170,\"longitude\":77.1950,\"locationPrecision\":\"Pinned\"}")
want_ok "Standalone post with a pin" "$R"
P2=$(echo "$R" | j id)
eq "Precision is Pinned" "$(echo "$R" | j locationPrecision)" "Pinned"
eq "District derived: Kanniyakumari" "$(sql "select district_id from hiring_posts where id='$P2'")" "$KK"
eq "Typed directions kept as written" "$(sql "select location from hiring_posts where id='$P2'")" "Near St. Mary's Church, Kuzhithurai"

R=$(post_ /business/hiring-posts "$BT" "{\"title\":\"Searched place\",\"eventDate\":\"$EV\",\"durationMinutes\":120,\"workersNeeded\":1,\"salaryAmount\":500,\"salaryUnit\":\"PerEvent\",\"latitude\":8.18,\"longitude\":77.41,\"locationPrecision\":\"Geocoded\"}")
eq "A searched place is stored as Geocoded" "$(echo "$R" | j locationPrecision)" "Geocoded"

R=$(post_ /business/hiring-posts "$BT" "{\"title\":\"No location\",\"eventDate\":\"$EV\",\"durationMinutes\":120,\"workersNeeded\":1,\"salaryAmount\":500,\"salaryUnit\":\"PerEvent\"}")
eq "A post with no pin stays unplaced (as before)" "$(echo "$R" | j locationPrecision)" "None"
want_no "Refused: only one coordinate on a post" "$(post_ /business/hiring-posts "$BT" "{\"title\":\"Half\",\"eventDate\":\"$EV\",\"durationMinutes\":120,\"workersNeeded\":1,\"salaryAmount\":500,\"salaryUnit\":\"PerEvent\",\"latitude\":8.3}")"

echo
echo "==== 7. EDITING A POST KEEPS OR MOVES THE PIN ===="
BODY="\"title\":\"Stage helpers\",\"eventDate\":\"$EV\",\"durationMinutes\":180,\"workersNeeded\":1,\"salaryAmount\":700,\"salaryUnit\":\"PerEvent\",\"location\":\"Near St. Mary's Church, Kuzhithurai\""
want_ok "Edit with no coordinates" "$(put_ /business/hiring-posts/$P2 "$BT" "{$BODY}")" ""
near "...keeps the pin it had" "$(sql "select latitude from hiring_posts where id='$P2'")" "8.3170"
want_ok "Edit with a new pin" "$(put_ /business/hiring-posts/$P2 "$BT" "{$BODY,\"latitude\":8.5241,\"longitude\":76.9366,\"locationPrecision\":\"Pinned\"}")" ""
near "...moves it" "$(sql "select latitude from hiring_posts where id='$P2'")" "8.5241"
TVM=$(sql "select id from districts where name ilike 'thiruvananthapuram' limit 1")
eq "...and re-derives the district (Thiruvananthapuram)" "$(sql "select district_id from hiring_posts where id='$P2'")" "$TVM"

echo
echo "==== 8. NAMING A PIN FILLS THE ADDRESS (map provider) ===="
R=$(get_ "/places/reverse?latitude=$JOB_LAT&longitude=$JOB_LON&precise=true" "$CT")
if echo "$R" | grep -q '"state"'; then
  eq "Precise lookup returns the state" "$(echo "$R" | j state)" "Tamil Nadu"
  PC=$(echo "$R" | j postalCode)
  if echo "$PC" | grep -qE '^6[0-9]{5}$'; then ok "...and a Tamil Nadu pincode" "$PC"; else bad "...and a Tamil Nadu pincode" "got '$PC'"; fi
  eq "...and keeps the caller's own point" "$(echo "$R" | n latitude | cut -c1-6)" "8.3123"
else
  bad "Precise lookup returns an address" "$(echo "$R" | cut -c1-120) (map provider unreachable?)"
fi
R=$(get_ "/places/reverse?latitude=8.3170&longitude=77.1950" "$WT")
if echo "$R" | grep -q '"name"'; then ok "Worker's suburb-level lookup still works" "$(echo "$R" | j name)"; else bad "Worker's suburb-level lookup still works" "$(echo "$R" | cut -c1-120)"; fi

echo
echo "================ RESULT: $PASS passed, $FAIL failed ================"
[ "$FAIL" -eq 0 ]
