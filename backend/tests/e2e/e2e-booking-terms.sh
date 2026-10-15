#!/usr/bin/env bash
# Agreeing the crew size and the price before an order is confirmed.
#
# The business needs 20 for the wedding; the customer says 18 is enough. Before this, Confirm was
# a bare yes — that conversation happened on the phone and the order still carried whatever the
# service template said. Now it happens in the app, every round is on record, and ACCEPTING the
# offer is what confirms the order.
#
# What this pins:
#   * the business offers, the customer counters, the business accepts — unlimited rounds
#   * you can never accept your own offer (the money bug: a business forcing its own price)
#   * plain Confirm is refused while an offer is open (the same bug through the other door)
#   * an offer replaced by a counter cannot be accepted afterwards
#   * exactly ONE offer is open at a time, enforced by the database, not just the handler
#   * the agreed crew and price land on the order in the same save that confirms it
#   * no offers once confirmed or cancelled
#   * the agreed count does NOT cap the roster — the business can still send more
API=http://localhost:5056/api/v1
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-95; }

ok()  { PASS=$((PASS+1)); printf 'PASS  %-58s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-58s %s\n' "$1" "$2"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }
want_ok()   { if echo "$2" | grep -q '"success":true'; then ok "$1" "$3"; else bad "$1" "$(echo "$2" | msg)"; fi; }
want_fail() { if echo "$2" | grep -q '"success":true'; then bad "$1" "it was accepted"; else ok "$1" "$(echo "$2" | msg)"; fi; }

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
get_()  { curl -s "$API$1" -H "Authorization: Bearer $2"; }
agreement() { get_ "/business/bookings/$BID" "$BT" | grep -o '"agreementStatus":"[^"]*"' | head -1 | cut -d'"' -f4; }
openid()    { sql "select id from booking_agreement_proposals where booking_id='$BID' and proposal_status=1 and is_deleted=false"; }

echo "================ SETUP ================"
BT=$(reg Boss "t_b$S@zuno.local" BusinessOwner | j accessToken)
CT=$(reg Asha "t_c$S@zuno.local" Customer | j accessToken)
WT=$(reg Ravi "t_w$S@zuno.local" Worker | j accessToken)
if [ -z "$BT" ] || [ -z "$CT" ]; then echo "registration failed (rate limit?)"; exit 1; fi
sql "update business_owner_profiles set verification_status=1, verified_at=now() where user_id=(select id from users where email='t_b$S@zuno.local')" >/dev/null
CAT=$(sql "select id from service_categories where slug='cleaning' and is_deleted=false")
DIST=$(sql "select id from districts where is_deleted=false limit 1")

# Priced per head, which is exactly the case where the crew size must be agreed.
SVC=$(post_ /business/services "$BT" "{\"serviceCategoryId\":\"$CAT\",\"name\":\"Wedding catering $S\",\"priceType\":\"PerPerson\",\"price\":500,\"requiredWorkerCount\":0,\"districtIds\":[\"$DIST\"]}" | j id)
SOON=$(date -u -d '+7 days 10:00' +%Y-%m-%dT%H:%M:%SZ)
BK=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$SOON\",\"addressLine1\":\"1 Road\",\"city\":\"Kochi\",\"state\":\"Kerala\",\"postalCode\":\"682001\"}")
BID=$(echo "$BK" | j id)
ok "A per-person order at 500 a head" "crew not yet agreed"
eq "It starts needing no agreement" "$(agreement)" "NotRequired"
eq "...and carries no crew size"    "$(sql "select required_worker_count from bookings where id='$BID'")" "0"

echo
echo "==== 1. THE BUSINESS OFFERS 20 ===="
want_ok "Business offers 20 at 10,000" \
  "$(post_ "/business/bookings/$BID/terms" "$BT" '{"workerCount":20,"price":10000,"message":"400 guests needs 5 servers per 100"}')" ""
eq "Now waiting on the customer" "$(agreement)" "AwaitingCustomer"
eq "One offer on the table"      "$(sql "select count(*) from booking_agreement_proposals where booking_id='$BID' and proposal_status=1")" "1"
eq "The order is still Pending"  "$(sql "select booking_status from bookings where id='$BID'")" "1"
P1=$(openid)

echo
echo "==== 2. THE LINE NEITHER SIDE MAY CROSS ===="
# The money bug this whole feature turns on.
want_fail "The business cannot accept its own offer" "$(post_ "/business/bookings/$BID/terms/$P1/accept" "$BT")"
# The same bug through the other door: Confirm would lock in the service's listed price instead.
want_fail "Plain Confirm is refused while an offer is open" "$(post_ "/business/bookings/$BID/confirm" "$BT")"
eq "...and the order is still Pending" "$(sql "select booking_status from bookings where id='$BID'")" "1"
# Its own offer is still live, so it may not pile a second one on top.
want_fail "Nor may it replace its own open offer" \
  "$(post_ "/business/bookings/$BID/terms" "$BT" '{"workerCount":19,"price":9500}')"
# Nobody else gets a say at all.
want_fail "A worker on the platform cannot offer terms" \
  "$(post_ "/customer/bookings/$BID/terms" "$WT" '{"workerCount":1,"price":1}')"

echo
echo "==== 3. THE CUSTOMER COUNTERS 18 ===="
want_ok "Customer counters 18 at 9,000" \
  "$(post_ "/customer/bookings/$BID/terms" "$CT" '{"workerCount":18,"price":9000,"message":"we have 2 of our own"}')" ""
eq "Back to waiting on the business" "$(agreement)" "AwaitingBusiness"
eq "STILL exactly one offer open"    "$(sql "select count(*) from booking_agreement_proposals where booking_id='$BID' and proposal_status=1")" "1"
eq "Two rounds on record"            "$(sql "select count(*) from booking_agreement_proposals where booking_id='$BID'")" "2"
eq "The first one was superseded"    "$(sql "select proposal_status from booking_agreement_proposals where id='$P1'")" "3"
want_fail "The replaced offer can no longer be accepted" "$(post_ "/business/bookings/$BID/terms/$P1/accept" "$BT")"
want_fail "The customer cannot accept their own counter" "$(post_ "/customer/bookings/$BID/terms/$(openid)/accept" "$CT")"

echo
echo "==== 4. THE BUSINESS ACCEPTS, AND THAT CONFIRMS THE ORDER ===="
P2=$(openid)
want_ok "Business accepts 18" "$(post_ "/business/bookings/$BID/terms/$P2/accept" "$BT")" ""
eq "Order is Confirmed (6)"          "$(sql "select booking_status from bookings where id='$BID'")" "6"
eq "Agreed crew landed on the order" "$(sql "select required_worker_count from bookings where id='$BID'")" "18"
eq "Agreed price landed too"         "$(sql "select price_quoted from bookings where id='$BID'")" "9000.00"
eq "Reads as agreed"                 "$(agreement)" "Agreed"
eq "Still two rounds — accepting adds none" "$(sql "select count(*) from booking_agreement_proposals where booking_id='$BID'")" "2"
eq "The customer sees the history"   "$(get_ /customer/bookings "$CT" | grep -c 'we have 2 of our own')" "1"

echo
echo "==== 5. THE TALKING IS OVER ===="
want_fail "No new offers once confirmed" "$(post_ "/business/bookings/$BID/terms" "$BT" '{"workerCount":25,"price":12500}')"
want_fail "Accepting again is refused"   "$(post_ "/business/bookings/$BID/terms/$P2/accept" "$BT")"
want_fail "The business still cannot cancel a confirmed order" \
  "$(post_ "/business/bookings/$BID/cancel" "$BT" '{"reason":"changed my mind"}')"

echo
echo "==== 6. AGREED IS NOT THE SAME AS ROSTERED ===="
# The existing rule survives untouched: what the customer pays for and how many people the
# business actually sends are two different numbers.
# Through the real invite-and-accept flow rather than a hand-written INSERT. The first version of
# this named a column that does not exist and silently added nobody, which then read as the cap
# rule failing when nothing had been tested at all.
post_ /business/workers/invite "$BT" "{\"workerIdentifier\":\"t_w$S@zuno.local\"}" >/dev/null
INV=$(get_ /worker/invitations "$WT" | tr '{' '\n' | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
post_ "/worker/invitations/$INV/respond" "$WT" '{"accept":true}' >/dev/null
WP=$(sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='t_w$S@zuno.local'")
eq "The worker joined the business" "$(sql "select count(*) from business_workers bw join business_owner_profiles b on b.id=bw.business_owner_profile_id where b.user_id=(select id from users where email='t_b$S@zuno.local') and bw.worker_profile_id='$WP' and bw.assignment_status=2")" "1"
want_ok "A 19th worker can still be assigned against an agreed 18" \
  "$(post_ "/business/bookings/$BID/assign-worker" "$BT" "{\"workerProfileId\":\"$WP\"}")" "no cap"
eq "The agreed number did not move" "$(sql "select required_worker_count from bookings where id='$BID'")" "18"

echo
echo "==== 7. AN ORDER NOBODY NEGOTIATED IS UNCHANGED ===="
PLAIN=$(post_ /business/services "$BT" "{\"serviceCategoryId\":\"$CAT\",\"name\":\"Plain clean $S\",\"priceType\":\"Fixed\",\"price\":800,\"requiredWorkerCount\":2,\"districtIds\":[\"$DIST\"]}" | j id)
B2=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$PLAIN\",\"scheduledDate\":\"$SOON\",\"addressLine1\":\"1 Road\",\"city\":\"Kochi\",\"state\":\"Kerala\",\"postalCode\":\"682001\"}")
B2ID=$(echo "$B2" | j id)
want_ok "Plain Confirm still works with no offer" "$(post_ "/business/bookings/$B2ID/confirm" "$BT")" "as before"
eq "Confirmed (6)"                 "$(sql "select booking_status from bookings where id='$B2ID'")" "6"
eq "Price untouched by any offer"  "$(sql "select price_quoted from bookings where id='$B2ID'")" "800.00"
eq "Crew still the service's own"  "$(sql "select required_worker_count from bookings where id='$B2ID'")" "2"
eq "Reads as needing no agreement" "$(get_ "/business/bookings/$B2ID" "$BT" | grep -o '"agreementStatus":"[^"]*"' | head -1 | cut -d'"' -f4)" "NotRequired"

echo
echo "================ $PASS passed, $FAIL failed ================"
[ "$FAIL" -eq 0 ]
