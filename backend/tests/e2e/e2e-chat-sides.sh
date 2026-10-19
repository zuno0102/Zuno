#!/usr/bin/env bash
# End-to-end: in an order's chat, each side sees its own messages as "mine" (right) and the other
# side's as not mine (left) — like WhatsApp — and every message is stamped with who really sent it.
API=${API:-http://localhost:5056/api/v1}
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
ok()  { PASS=$((PASS+1)); printf 'PASS  %-58s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-58s %s\n' "$1" "$2"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }

reg() {
  curl -s -X POST $API/auth/register -H 'Content-Type: application/json' \
    -d "{\"firstName\":\"$1\",\"lastName\":\"T\",\"email\":\"$2\",\"password\":\"E2e@12345\",\"phoneNumber\":\"9$((RANDOM%900000000+100000000))\",\"role\":\"$3\"}"
}
post_() { curl -s -X POST "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "${3:-{\}}"; }
get_()  { curl -s "$API$1" -H "Authorization: Bearer $2"; }

# isMine of the message with this body, from one viewer's copy of the thread.
mine_of() { echo "$1" | tr '{' '\n' | grep "\"body\":\"$2\"" | grep -o '"isMine":[a-z]*' | cut -d: -f2; }

echo "================ SETUP ================"
BT=$(reg Boss "cs_b$S@zuno.local" BusinessOwner | j accessToken)
CT=$(reg Cust "cs_c$S@zuno.local" Customer | j accessToken)
if [ -z "$BT" ] || [ -z "$CT" ]; then echo "registration failed (rate limit?)"; exit 1; fi
BIZ=$(sql "select b.id from business_owner_profiles b join users u on u.id=b.user_id where u.email='cs_b$S@zuno.local'")
sql "update business_owner_profiles set verification_status=1, verified_at=now() where id='$BIZ'" >/dev/null
DIST=$(sql "select id from districts limit 1")
SVC=$(post_ /business/services "$BT" "{\"serviceCategoryId\":\"a1111111-0000-0000-0000-000000000003\",\"name\":\"Home wall painting\",\"priceType\":\"Fixed\",\"price\":5000,\"requiredWorkerCount\":1,\"districtIds\":[\"$DIST\"]}" | j id)
WHEN=$(date -u -d '+10 days 10:00' +%Y-%m-%dT%H:%M:%SZ)
BK=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$WHEN\",\"addressLine1\":\"1 Road\",\"city\":\"Verkilambi\",\"state\":\"Tamil Nadu\",\"postalCode\":\"629175\",\"latitude\":8.2985,\"longitude\":77.2705}" | j id)
post_ /business/bookings/$BK/confirm "$BT" >/dev/null
eq "Order placed and confirmed" "$(sql "select booking_status from bookings where id='$BK'")" "6"

echo
echo "==== Business says Hai, customer says Hello ===="
post_ /bookings/$BK/messages "$BT" '{"body":"Hai"}' >/dev/null
post_ /bookings/$BK/messages "$CT" '{"body":"Hello"}' >/dev/null
eq "Hai stored as sent by the Business (2)" "$(sql "select sender_role from booking_messages where booking_id='$BK' and body='Hai'")" "2"
eq "Hello stored as sent by the Customer (1)" "$(sql "select sender_role from booking_messages where booking_id='$BK' and body='Hello'")" "1"

CUST_VIEW=$(get_ /bookings/$BK/messages "$CT")
eq "Customer view: Hai is the other side's (left)" "$(mine_of "$CUST_VIEW" Hai)" "false"
eq "Customer view: Hello is mine (right)" "$(mine_of "$CUST_VIEW" Hello)" "true"

BIZ_VIEW=$(get_ /bookings/$BK/messages "$BT")
eq "Business view: Hai is mine (right)" "$(mine_of "$BIZ_VIEW" Hai)" "true"
eq "Business view: Hello is the other side's (left)" "$(mine_of "$BIZ_VIEW" Hello)" "false"

echo
echo "================ RESULT: $PASS passed, $FAIL failed ================"
[ "$FAIL" -eq 0 ]
