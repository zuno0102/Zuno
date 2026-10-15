#!/usr/bin/env bash
# The invite picker must only offer jobs whose order is still live.
#
# A hiring post does not close itself when its order completes or is cancelled, so its own
# status keeps reading "Open" long after there is anything left to staff. These checks cover
# the field the client filters on, and the server guard behind it.
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
want_no() { if echo "$2" | grep -q '"success":false'; then ok "$1" "$(echo "$2" | msg)"; else bad "$1" "allowed but should have been refused"; fi; }
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

# The bookingStatus the API reports for one post.
status_of() {
  get_ /business/hiring-posts "$1" \
    | tr '{' '\n' | grep "\"id\":\"$2\"" \
    | grep -o '"bookingStatus":[^,}]*' | head -1 | cut -d: -f2 | tr -d '"'
}

echo "================ SETUP ================"
BT=$(reg Boss "iv_b$S@zuno.local" BusinessOwner | j accessToken)
CT=$(reg Cust "iv_c$S@zuno.local" Customer | j accessToken)
W1=$(reg Wone "iv_w1$S@zuno.local" Worker | j accessToken)
W2=$(reg Wtwo "iv_w2$S@zuno.local" Worker | j accessToken)
if [ -z "$BT" ] || [ -z "$CT" ] || [ -z "$W1" ] || [ -z "$W2" ]; then
  echo "registration failed (rate limit?)"; exit 1
fi
ok "Registered business, customer, 2 workers" "iv_b$S@zuno.local"

BIZ=$(sql "select b.id from business_owner_profiles b join users u on u.id=b.user_id where u.email='iv_b$S@zuno.local'")
sql "update business_owner_profiles set verification_status=1, verified_at=now() where id='$BIZ'" >/dev/null
DIST=$(sql "select id from districts limit 1")
CAT=a1111111-0000-0000-0000-000000000003

SVC=$(post_ /business/services "$BT" "{\"serviceCategoryId\":\"$CAT\",\"name\":\"Catering\",\"priceType\":\"Fixed\",\"price\":5000,\"requiredWorkerCount\":1,\"districtIds\":[\"$DIST\"]}" | j id)
eq "Service created" "$([ -n "$SVC" ] && echo yes)" "yes"

WHEN=$(date -u -d '+10 days 10:00' +%Y-%m-%dT%H:%M:%SZ)

# Three orders, so each end-state can be checked without disturbing the others.
mk_booking() {
  post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$WHEN\",\"addressLine1\":\"14 Nila Nagar\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"country\":\"India\"}" | j id
}
mk_post() {
  post_ /business/hiring-posts "$BT" "{\"bookingId\":\"$1\",\"title\":\"$2\",\"eventDate\":\"$WHEN\",\"durationMinutes\":240,\"workersNeeded\":3,\"salaryAmount\":700,\"salaryUnit\":\"PerEvent\",\"location\":\"14 Nila Nagar\"}" | j id
}

BK_LIVE=$(mk_booking);  BK_DONE=$(mk_booking);  BK_OFF=$(mk_booking)
want_ok "Three orders placed and confirmed" "$(post_ /business/bookings/$BK_LIVE/confirm "$BT")" ""
post_ /business/bookings/$BK_DONE/confirm "$BT" >/dev/null
post_ /business/bookings/$BK_OFF/confirm  "$BT" >/dev/null

P_LIVE=$(mk_post "$BK_LIVE" "Still on");  P_DONE=$(mk_post "$BK_DONE" "Finished order")
P_OFF=$(mk_post "$BK_OFF" "Called off");  P_ALONE=$(post_ /business/hiring-posts "$BT" "{\"title\":\"Our own event\",\"eventDate\":\"$WHEN\",\"durationMinutes\":240,\"workersNeeded\":3,\"salaryAmount\":700,\"salaryUnit\":\"PerEvent\",\"location\":\"Depot\"}" | j id)
eq "Four posts created" "$([ -n "$P_LIVE" ] && [ -n "$P_DONE" ] && [ -n "$P_OFF" ] && [ -n "$P_ALONE" ] && echo yes)" "yes"

echo
echo "==== 1. THE API REPORTS EACH ORDER'S STATE ===="
eq "Live order reports Confirmed" "$(status_of "$BT" "$P_LIVE")" "Confirmed"
eq "Standalone post reports no order at all" "$(status_of "$BT" "$P_ALONE")" "null"

# Completed and Cancelled, reached the way the app reaches them.
sql "update bookings set booking_status=4, completed_at=now() where id='$BK_DONE'" >/dev/null
want_ok "Customer cancels the third order" "$(post_ /customer/bookings/$BK_OFF/cancel "$CT" '{"cancellationReason":"Changed our plans"}')" ""

eq "Completed order reports Completed" "$(status_of "$BT" "$P_DONE")" "Completed"
eq "Cancelled order reports Cancelled"  "$(status_of "$BT" "$P_OFF")"  "Cancelled"

echo
echo "==== 2. THE POSTS THEMSELVES STAY OPEN — WHICH IS THE POINT ===="
# If a finished order closed its post, the post's own status would be enough and none of this
# would be needed. It does not, so the client cannot filter on status alone.
eq "Post behind the completed order is still Open" "$(sql "select hiring_post_status from hiring_posts where id='$P_DONE'")" "1"

echo
echo "==== 3. THE SERVER REFUSES INVITES TO DEAD ORDERS ===="
want_ok "Invite allowed on the live order"          "$(post_ /business/hiring-posts/$P_LIVE/invite "$BT" "{\"workerIdentifier\":\"iv_w1$S@zuno.local\"}")" ""
want_no "Refused: order already completed"          "$(post_ /business/hiring-posts/$P_DONE/invite "$BT" "{\"workerIdentifier\":\"iv_w2$S@zuno.local\"}")"
want_no "Refused: order was cancelled"              "$(post_ /business/hiring-posts/$P_OFF/invite  "$BT" "{\"workerIdentifier\":\"iv_w2$S@zuno.local\"}")"

echo
echo "==== 4. REGRESSION: STANDALONE POSTS ARE UNAFFECTED ===="
want_ok "Invite still allowed on a post with no order" "$(post_ /business/hiring-posts/$P_ALONE/invite "$BT" "{\"workerIdentifier\":\"iv_w2$S@zuno.local\"}")" ""

echo
echo "==== 5. THE INVITE RESPONSE KEEPS THE ORDER ATTACHED ===="
# Without the Include it would come back looking standalone and the client would re-list it.
R=$(post_ /business/hiring-posts/$P_LIVE/invite "$BT" "{\"workerIdentifier\":\"iv_w2$S@zuno.local\"}")
BS=$(echo "$R" | grep -o '"bookingStatus":[^,}]*' | head -1 | cut -d: -f2 | tr -d '"')
eq "Response still names the order's state" "$BS" "Confirmed"

echo
echo "================ $PASS passed, $FAIL failed ================"
[ "$FAIL" -eq 0 ]
