#!/usr/bin/env bash
# Pricing a service by the head, for catering and anything else where the crew size is the job.
#
# Before this there were three price types — Fixed, Hourly, Daily — and every one of them assumed
# the total was known when the service was listed. A caterer charging ₹500 a head cannot say what
# a wedding costs until somebody says how many guests, and that number is settled with the
# customer after the booking arrives.
#
# What this pins:
#   * a service can be priced per person, and then carries a crew size of 0
#   * 0 means "agreed per order", so it is refused for every other price type
#   * a fixed crew size is refused ON a per-person service — one decider, not two
#   * the price type is snapshotted onto the booking, so repricing the service later cannot
#     restate what an old order was quoted in
#   * every price type that worked before still works, unchanged
API=${API:-http://localhost:5056/api/v1}
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-95; }
err() { tr '[' '\n' | grep -o '"[^"]*must[^"]*"\|"[^"]*agree[^"]*"\|"[^"]*price it per person[^"]*"' | head -1 | tr -d '"' | cut -c1-95; }

ok()  { PASS=$((PASS+1)); printf 'PASS  %-56s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-56s %s\n' "$1" "$2"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }
has_id()    { if echo "$2" | grep -q '"id"'; then ok "$1" "$3"; else bad "$1" "$(echo "$2" | msg)"; fi; }
want_fail() { if echo "$2" | grep -q '"id"'; then bad "$1" "it was accepted"; else ok "$1" "$(echo "$2" | err)"; fi; }

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
put_()  { curl -s -X PUT  "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "${3:-\{\}}"; }
get_()  { curl -s "$API$1" -H "Authorization: Bearer $2"; }

svc() { # priceType workers price name
  post_ /business/services "$BT" \
    "{\"serviceCategoryId\":\"$CAT\",\"name\":\"$4\",\"priceType\":\"$1\",\"price\":$3,\"requiredWorkerCount\":$2,\"districtIds\":[\"$DIST\"]}"
}

echo "================ SETUP ================"
BT=$(reg Boss "pp_b$S@zuno.local" BusinessOwner | j accessToken)
CT=$(reg Asha "pp_c$S@zuno.local" Customer | j accessToken)
if [ -z "$BT" ] || [ -z "$CT" ]; then echo "registration failed (rate limit?)"; exit 1; fi
sql "update business_owner_profiles set verification_status=1, verified_at=now() where user_id=(select id from users where email='pp_b$S@zuno.local')" >/dev/null
CAT=$(sql "select id from service_categories where slug='cleaning' and is_deleted=false")
DIST=$(sql "select id from districts where is_deleted=false limit 1")
ok "Registered a business and a customer" "pp_b$S@zuno.local"
# Every order this run places records a price type, so this number must not move.
UNTYPED_BEFORE=$(sql "select count(*) from bookings where price_type is null")
ok "Orders predating the price type" "$UNTYPED_BEFORE"

echo
echo "==== 1. A SERVICE PRICED BY THE HEAD ===="
R=$(svc PerPerson 0 500 "Wedding catering $S")
has_id "Listed at 500 a head, crew size 0" "$R" "per person"
SVC=$(echo "$R" | j id)
eq "Stored as PerPerson (4)"  "$(sql "select price_type from business_services where id='$SVC'")" "4"
eq "...with a crew size of 0" "$(sql "select required_worker_count from business_services where id='$SVC'")" "0"

echo
echo "==== 2. ZERO MEANS 'AGREED PER ORDER', NOT 'NOBODY NEEDED' ===="
# It is a real answer for any price type: a wedding package can be a flat 50,000 and still need a
# crew that only the guest count decides.
R=$(svc Fixed  0 50000 "Flat wedding package $S"); has_id "A fixed price may have 0 workers"  "$R" "agreed per order"
R=$(svc Hourly 0 250   "Hourly, crew varies $S");  has_id "So may an hourly one"              "$R" "agreed per order"
R=$(svc Daily  0 2000  "Daily, crew varies $S");   has_id "So may a daily one"                "$R" "agreed per order"
# What is refused is a number that cannot mean anything.
want_fail "A negative crew size is refused" "$(svc Fixed -2 5000 "Bad negative $S")"
# And the other way: on a per-person service two numbers claim to decide the crew, one too many.
want_fail "A per-person service cannot fix a crew size" "$(svc PerPerson 15 500 "Bad perperson $S")"

echo
echo "==== 3. THE PRICE TYPES THAT WORKED BEFORE STILL WORK ===="
R=$(svc Fixed 1 5000 "Deep clean $S");   has_id "Fixed, 1 worker"  "$R" "unchanged"
FIXED=$(echo "$R" | j id)
R=$(svc Hourly 2 250 "Hourly help $S");  has_id "Hourly, 2 workers" "$R" "unchanged"
R=$(svc Daily 3 2000 "Daily crew $S");   has_id "Daily, 3 workers"  "$R" "unchanged"

echo
echo "==== 4. THE ORDER REMEMBERS WHAT THE PRICE MEANT ===="
SOON=$(date -u -d '+5 days 10:00' +%Y-%m-%dT%H:%M:%SZ)
BK=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$SOON\",\"addressLine1\":\"1 Road\",\"city\":\"Kochi\",\"state\":\"Kerala\",\"postalCode\":\"682001\",\"latitude\":9.9312,\"longitude\":76.2673}")
has_id "Customer books the per-person service" "$BK" ""
BID=$(echo "$BK" | j id)
eq "The order carries the rate"        "$(sql "select price_quoted from bookings where id='$BID'")" "500.00"
eq "...and that it is per person (4)"  "$(sql "select price_type from bookings where id='$BID'")" "4"
eq "...and a crew size of 0, still to be agreed" "$(sql "select required_worker_count from bookings where id='$BID'")" "0"
eq "The customer is told the price type" "$(get_ /customer/bookings "$CT" | tr '{' '\n' | grep -o '"priceType":"[^"]*"' | head -1 | cut -d'"' -f4)" "PerPerson"

# The reason it is snapshotted rather than read live off the service.
BK2=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$FIXED\",\"scheduledDate\":\"$SOON\",\"addressLine1\":\"1 Road\",\"city\":\"Kochi\",\"state\":\"Kerala\",\"postalCode\":\"682001\",\"latitude\":9.9312,\"longitude\":76.2673}")
BID2=$(echo "$BK2" | j id)
eq "A fixed-price order records Fixed (1)" "$(sql "select price_type from bookings where id='$BID2'")" "1"
want_ok_r=$(put_ "/business/services/$FIXED" "$BT" "{\"id\":\"$FIXED\",\"serviceCategoryId\":\"$CAT\",\"name\":\"Deep clean $S\",\"priceType\":\"Hourly\",\"price\":250,\"requiredWorkerCount\":1,\"districtIds\":[\"$DIST\"]}")
has_id "The business reprices that service to Hourly" "$want_ok_r" "service changed"
eq "The order placed earlier still reads Fixed (1)" "$(sql "select price_type from bookings where id='$BID2'")" "1"

echo
echo "==== 5. NOTHING ELSE MOVED ===="
# Pinned against a count taken at the start of this run, not a moving time window. The first
# version compared "older than an hour" against itself, so bookings made by an earlier run of
# this very script aged into the window and broke it — a test that fails with the clock rather
# than with the code.
eq "The migration backfilled nothing: old orders still have no price type" \
   "$(sql "select count(*) from bookings where price_type is null")" "$UNTYPED_BEFORE"
eq "A per-person order is not counted as fully staffed" \
   "$(get_ /business/bookings "$BT" | tr '{' '\n' | grep -c '"crewStatus":"FullyStaffed"' || true)" "0"

echo
echo "================ $PASS passed, $FAIL failed ================"
[ "$FAIL" -eq 0 ]
