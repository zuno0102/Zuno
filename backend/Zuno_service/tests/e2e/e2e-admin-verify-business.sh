#!/usr/bin/env bash
# The gate every business waits behind: approval.
#
# A business registers as Pending and is invisible to customers until the app owner approves it.
# Every other scenario reached that state by writing to the database directly, so the endpoints
# that actually make the decision had never been exercised — which is the one part of this flow a
# business cannot work around and the app owner cannot avoid.
#
# What this pins:
#   * a new business is Pending, and a customer cannot find it
#   * the review list shows it, and filters by status
#   * approving makes it findable, and records when
#   * rejecting keeps it hidden, and a rejected business can still be approved later
#   * nobody but the app owner can reach any of it — not the business itself, not a customer
#   * approving something that does not exist is a 404, not a surprise
API=${API:-http://localhost:5056/api/v1}
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-80; }

ok()  { PASS=$((PASS+1)); printf 'PASS  %-54s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-54s %s\n' "$1" "$2"; }
want_ok()   { if echo "$2" | grep -q '"success":true'; then ok "$1" "$3"; else bad "$1" "$(echo "$2" | msg)"; fi; }
want_fail() { if echo "$2" | grep -q '"success":true'; then bad "$1" "ACCEPTED — the rule should have refused it"; else ok "$1" "$(echo "$2" | msg)"; fi; }
eq()        { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }
step()      { printf '\n==== %s ====\n' "$1"; }

reg() { curl -s -X POST $API/auth/register -H 'Content-Type: application/json' \
  -d "{\"firstName\":\"$1\",\"lastName\":\"V\",\"email\":\"$2\",\"password\":\"E2e@12345\",\"phoneNumber\":\"9$(shuf -i 100000000-999999999 -n 1)\",\"role\":\"$3\"}"; }
login() { curl -s -X POST $API/auth/login -H 'Content-Type: application/json' \
  -d "{\"emailOrPhone\":\"$1\",\"password\":\"$2\"}"; }
P()  { local b="${3:-{\}}"; curl -s -X POST "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$b"; }
PU() { curl -s -X PUT "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$3"; }
G()  { curl -s "$API$1" -H "Authorization: Bearer $2"; }
code() { curl -s -o /dev/null -w '%{http_code}' -X "$1" "$API$2" -H "Authorization: Bearer $3"; }

echo "=============================================================="
echo " THE APPROVAL GATE   $(date '+%Y-%m-%d %H:%M')"
echo "=============================================================="

step "0. THE PEOPLE INVOLVED"
AD=$(login admin@zuno.local 'Admin@12345' | j accessToken)
eq "The app owner signed in" "$([ -n "$AD" ] && echo yes)" "yes"
[ -n "$AD" ] || { echo "ABORTED: no admin token"; exit 1; }

BT=$(reg Hopeful "verify_b$S@zuno.local" BusinessOwner | j accessToken)
B2=$(reg Refused "verify_r$S@zuno.local" BusinessOwner | j accessToken)
CT=$(reg Asha    "verify_c$S@zuno.local" Customer      | j accessToken)
WT=$(reg Ravi    "verify_w$S@zuno.local" Worker        | j accessToken)
eq "Two businesses and a customer signed up" \
   "$([ -n "$BT" ] && [ -n "$B2" ] && [ -n "$CT" ] && [ -n "$WT" ] && echo yes)" "yes"
[ -n "$BT" ] && [ -n "$B2" ] && [ -n "$CT" ] && [ -n "$WT" ] || { echo "ABORTED"; exit 1; }

BIZ=$(sql "select b.id from business_owner_profiles b join users u on u.id=b.user_id where u.email='verify_b$S@zuno.local'")
BIZ2=$(sql "select b.id from business_owner_profiles b join users u on u.id=b.user_id where u.email='verify_r$S@zuno.local'")
DIST=$(sql "select id from districts limit 1")
CAT=$(sql "select id from service_categories where is_active order by name limit 1")

NAME="Gatekept Catering $S"
want_ok "The business names itself" "$(PU /business/profile "$BT" "{\"businessName\":\"$NAME\",\"description\":\"Weddings\",\"yearsOfExperience\":3}")" "$NAME"
SVC=$(P /business/services "$BT" "{\"serviceCategoryId\":\"$CAT\",\"name\":\"Gate test feast $S\",\"description\":\"d\",\"priceType\":\"Fixed\",\"price\":9000,\"requiredWorkerCount\":2,\"estimatedDurationMinutes\":240,\"districtIds\":[\"$DIST\"]}" | j id)
eq "...and lists a service" "$([ -n "$SVC" ] && echo yes)" "yes"

step "1. UNTIL SOMEBODY APPROVES IT, IT DOES NOT EXIST"
eq "It starts Pending"              "$(sql "select verification_status from business_owner_profiles where id='$BIZ'")" "0"
eq "...with no approval date"       "$(sql "select verified_at is null from business_owner_profiles where id='$BIZ'")" "t"
eq "A customer cannot find it"      "$(G "/customer/services?page=1&pageSize=50" "$CT" | grep -c "Gate test feast $S")" "0"
eq "...and the business knows why"  "$(G /business/profile "$BT" | grep -c '"verificationStatus":"Pending"')" "1"

step "2. ONLY THE APP OWNER DECIDES"
eq "The business cannot approve itself"      "$(code POST "/admin/businesses/$BIZ/approve" "$BT")" "403"
eq "A customer cannot approve it"            "$(code POST "/admin/businesses/$BIZ/approve" "$CT")" "403"
eq "A worker cannot approve it"              "$(code POST "/admin/businesses/$BIZ/approve" "$WT")" "403"
eq "A business cannot read the review list"  "$(code GET  "/admin/businesses" "$BT")" "403"
eq "Nobody signed in cannot either"          "$(curl -s -o /dev/null -w '%{http_code}' "$API/admin/businesses")" "401"
eq "...and it is still Pending"              "$(sql "select verification_status from business_owner_profiles where id='$BIZ'")" "0"

step "3. THE REVIEW LIST"
PENDING=$(G "/admin/businesses?status=Pending" "$AD")
eq "The waiting business is on it"      "$(echo "$PENDING" | grep -c "$NAME")" "1"
eq "Filtering by Verified excludes it"  "$(G "/admin/businesses?status=Verified" "$AD" | grep -c "$NAME")" "0"
eq "The unfiltered list includes it"    "$(G "/admin/businesses" "$AD" | grep -c "$NAME")" "1"

step "4. APPROVED"
want_ok "The app owner approves it" "$(P "/admin/businesses/$BIZ/approve" "$AD")" ""
eq "Now Verified"                   "$(sql "select verification_status from business_owner_profiles where id='$BIZ'")" "1"
eq "...and the moment was recorded" "$(sql "select verified_at is not null from business_owner_profiles where id='$BIZ'")" "t"
eq "The customer can now find it"   "$(G "/customer/services?page=1&pageSize=50" "$CT" | grep -c "Gate test feast $S")" "1"
eq "...and the profile says so"     "$(G /business/profile "$BT" | grep -c '"verificationStatus":"Verified"')" "1"
eq "It has left the pending list"   "$(G "/admin/businesses?status=Pending" "$AD" | grep -c "$NAME")" "0"

step "5. REJECTED"
NAME2="Turned Down $S"
want_ok "The second business names itself" "$(PU /business/profile "$B2" "{\"businessName\":\"$NAME2\",\"description\":\"x\",\"yearsOfExperience\":1}")" ""
SVC2=$(P /business/services "$B2" "{\"serviceCategoryId\":\"$CAT\",\"name\":\"Rejected feast $S\",\"description\":\"d\",\"priceType\":\"Fixed\",\"price\":1000,\"requiredWorkerCount\":1,\"estimatedDurationMinutes\":60,\"districtIds\":[\"$DIST\"]}" | j id)
want_ok "The app owner rejects it"  "$(P "/admin/businesses/$BIZ2/reject" "$AD")" ""
eq "Now Rejected"                   "$(sql "select verification_status from business_owner_profiles where id='$BIZ2'")" "2"
eq "A customer still cannot find it" "$(G "/customer/services?page=1&pageSize=50" "$CT" | grep -c "Rejected feast $S")" "0"
eq "...and the business is told"     "$(G /business/profile "$B2" | grep -c '"verificationStatus":"Rejected"')" "1"

step "6. A DECISION CAN BE CHANGED"
want_ok "The rejected business is approved after all" "$(P "/admin/businesses/$BIZ2/approve" "$AD")" ""
eq "Now Verified"                    "$(sql "select verification_status from business_owner_profiles where id='$BIZ2'")" "1"
eq "...and findable"                 "$(G "/customer/services?page=1&pageSize=50" "$CT" | grep -c "Rejected feast $S")" "1"
want_ok "And approved again, harmlessly" "$(P "/admin/businesses/$BIZ2/approve" "$AD")" ""
eq "...still Verified"               "$(sql "select verification_status from business_owner_profiles where id='$BIZ2'")" "1"

step "7. THE OBVIOUS MISTAKES"
eq "Approving a business that does not exist" "$(code POST "/admin/businesses/$(uuidgen 2>/dev/null || echo 11111111-1111-1111-1111-111111111111)/approve" "$AD")" "404"
eq "A nonsense status filter returns something sane" \
   "$(curl -s -o /dev/null -w '%{http_code}' "$API/admin/businesses?status=Banana" -H "Authorization: Bearer $AD")" "200"

echo
echo "================ $PASS passed, $FAIL failed ================"
[ "$FAIL" -eq 0 ]
