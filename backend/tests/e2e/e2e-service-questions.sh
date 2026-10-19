#!/usr/bin/env bash
# A business asking its own questions, so it can staff the job properly.
#
# "Wedding catering" is not one job. 400 guests with 12 dishes and 50 with 4 look identical to a
# business whose only channel is an optional two-line notes box. So the business writes the boxes
# it needs — dish count, serving count, wall sizes — and every customer booking that service fills
# them in.
#
# What this pins:
#   * a business writes its own questions, and the customer sees exactly those
#   * a required question cannot be skipped
#   * an answer to another service's question is refused
#   * the wording is FROZEN onto the answer, so rewording or retiring a question later never
#     changes what an old order says it was told
#   * a service with no questions books exactly as it always did
API=http://localhost:5056/api/v1
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-90; }
errs(){ tr '[' '\n' | grep -o '"[^"]*required[^"]*"\|"[^"]*do not match[^"]*"' | head -1 | tr -d '"' | cut -c1-90; }

ok()  { PASS=$((PASS+1)); printf 'PASS  %-56s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-56s %s\n' "$1" "$2"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }
has_id()    { if echo "$2" | grep -q '"id"'; then ok "$1" "$3"; else bad "$1" "$(echo "$2" | msg)"; fi; }
want_fail() { if echo "$2" | grep -q '"id"'; then bad "$1" "it was accepted"; else ok "$1" "$(echo "$2" | errs)"; fi; }

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

echo "================ SETUP ================"
BT=$(reg Boss "q_b$S@zuno.local" BusinessOwner | j accessToken)
CT=$(reg Asha "q_c$S@zuno.local" Customer | j accessToken)
if [ -z "$BT" ] || [ -z "$CT" ]; then echo "registration failed (rate limit?)"; exit 1; fi
sql "update business_owner_profiles set verification_status=1, verified_at=now() where user_id=(select id from users where email='q_b$S@zuno.local')" >/dev/null
CAT=$(sql "select id from service_categories where slug='cleaning' and is_deleted=false")
DIST=$(sql "select id from districts where is_deleted=false limit 1")

SVC=$(post_ /business/services "$BT" "{\"serviceCategoryId\":\"$CAT\",\"name\":\"Wedding catering $S\",\"priceType\":\"PerPerson\",\"price\":500,\"requiredWorkerCount\":0,\"districtIds\":[\"$DIST\"]}" | j id)
OTHER=$(post_ /business/services "$BT" "{\"serviceCategoryId\":\"$CAT\",\"name\":\"House painting $S\",\"priceType\":\"Fixed\",\"price\":9000,\"requiredWorkerCount\":2,\"districtIds\":[\"$DIST\"]}" | j id)
ok "A catering service and a painting service" "per person / fixed"

echo
echo "==== 1. THE BUSINESS WRITES ITS OWN BOXES ===="
R=$(put_ "/business/services/$SVC/questions" "$BT" '{"questions":[
  {"prompt":"Enter your dishes count","isRequired":true},
  {"prompt":"Enter your items","isRequired":true},
  {"prompt":"Total serving items","isRequired":false}]}')
has_id "Three questions saved" "$R" ""
eq "Three stored, in order" "$(sql "select count(*) from business_service_questions where business_service_id='$SVC' and is_deleted=false")" "3"
eq "First one is first"     "$(sql "select prompt from business_service_questions where business_service_id='$SVC' and sort_order=0 and is_deleted=false")" "Enter your dishes count"

# A painter asks completely different things — nothing here is hardcoded.
put_ "/business/services/$OTHER/questions" "$BT" '{"questions":[{"prompt":"Wall size details","isRequired":true}]}' >/dev/null
eq "The painting service asks its own" "$(sql "select prompt from business_service_questions where business_service_id='$OTHER' and is_deleted=false")" "Wall size details"

echo
echo "==== 2. THE CUSTOMER SEES EXACTLY THOSE ===="
SEEN=$(get_ "/customer/services/$SVC" "$CT")
eq "All three reach the booking form" "$(echo "$SEEN" | grep -o '"prompt":"[^"]*"' | wc -l | tr -d ' ')" "3"
eq "...worded as the business wrote them" "$(echo "$SEEN" | grep -o '"prompt":"[^"]*"' | head -1 | cut -d'"' -f4)" "Enter your dishes count"

Q1=$(sql "select id from business_service_questions where business_service_id='$SVC' and sort_order=0 and is_deleted=false")
Q2=$(sql "select id from business_service_questions where business_service_id='$SVC' and sort_order=1 and is_deleted=false")
Q3=$(sql "select id from business_service_questions where business_service_id='$SVC' and sort_order=2 and is_deleted=false")
QO=$(sql "select id from business_service_questions where business_service_id='$OTHER' and is_deleted=false")

echo
echo "==== 3. ANSWERING ===="
SOON=$(date -u -d '+6 days 10:00' +%Y-%m-%dT%H:%M:%SZ)
ADDR="\"addressLine1\":\"1 Road\",\"city\":\"Kochi\",\"state\":\"Kerala\",\"postalCode\":\"682001\",\"latitude\":9.9312,\"longitude\":76.2673"

want_fail "A required question cannot be skipped" \
  "$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$SOON\",$ADDR,\"answers\":[{\"questionId\":\"$Q1\",\"answerText\":\"12\"}]}")"
want_fail "Nor answered with blank space" \
  "$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$SOON\",$ADDR,\"answers\":[{\"questionId\":\"$Q1\",\"answerText\":\"12\"},{\"questionId\":\"$Q2\",\"answerText\":\"   \"}]}")"
want_fail "A question from another service is refused" \
  "$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$SOON\",$ADDR,\"answers\":[{\"questionId\":\"$Q1\",\"answerText\":\"12\"},{\"questionId\":\"$Q2\",\"answerText\":\"biryani\"},{\"questionId\":\"$QO\",\"answerText\":\"sneaky\"}]}")"

BK=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$SOON\",$ADDR,\"answers\":[
  {\"questionId\":\"$Q1\",\"answerText\":\"12\"},
  {\"questionId\":\"$Q2\",\"answerText\":\"biryani, paneer, gulab jamun\"},
  {\"questionId\":\"$Q3\",\"answerText\":\"400\"}]}")
has_id "Booked with the full brief" "$BK" ""
BID=$(echo "$BK" | j id)
eq "Three answers stored" "$(sql "select count(*) from booking_service_answers where booking_id='$BID' and is_deleted=false")" "3"
eq "The wording was copied onto the answer" "$(sql "select question_prompt from booking_service_answers where booking_id='$BID' and sort_order=0 and is_deleted=false")" "Enter your dishes count"
eq "...along with what the customer typed"  "$(sql "select answer_text from booking_service_answers where booking_id='$BID' and sort_order=0 and is_deleted=false")" "12"

echo
echo "==== 4. THE BUSINESS READS THE BRIEF ===="
SEEN=$(get_ /business/bookings "$BT")
eq "The answers reach the business"   "$(echo "$SEEN" | grep -c 'biryani, paneer, gulab jamun')" "1"
eq "The customer sees their own too"  "$(get_ /customer/bookings "$CT" | grep -c 'biryani, paneer, gulab jamun')" "1"

echo
echo "==== 5. REWORDING LATER CHANGES NOTHING ALREADY ANSWERED ===="
put_ "/business/services/$SVC/questions" "$BT" "{\"questions\":[
  {\"id\":\"$Q1\",\"prompt\":\"How many dishes?\",\"isRequired\":true},
  {\"id\":\"$Q2\",\"prompt\":\"Enter your items\",\"isRequired\":true}]}" >/dev/null
eq "The question now reads differently" "$(sql "select prompt from business_service_questions where id='$Q1'")" "How many dishes?"
eq "The old order still reads the OLD wording" "$(sql "select question_prompt from booking_service_answers where booking_id='$BID' and sort_order=0 and is_deleted=false")" "Enter your dishes count"
# The third question was dropped from the list.
eq "The dropped question is hidden, not destroyed" "$(sql "select is_deleted from business_service_questions where id='$Q3'")" "t"
eq "...and its answer survives"                    "$(sql "select answer_text from booking_service_answers where booking_id='$BID' and sort_order=2 and is_deleted=false")" "400"
eq "The booking form now offers two"               "$(get_ "/customer/services/$SVC" "$CT" | grep -o '"prompt":"[^"]*"' | wc -l | tr -d ' ')" "2"
eq "Editing kept the question's id"                "$(sql "select count(*) from business_service_questions where id='$Q1' and business_service_id='$SVC'")" "1"

echo
echo "==== 6. A SERVICE WITH NO QUESTIONS IS UNCHANGED ===="
PLAIN=$(post_ /business/services "$BT" "{\"serviceCategoryId\":\"$CAT\",\"name\":\"Plain clean $S\",\"priceType\":\"Fixed\",\"price\":800,\"requiredWorkerCount\":1,\"districtIds\":[\"$DIST\"]}" | j id)
B2=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$PLAIN\",\"scheduledDate\":\"$SOON\",$ADDR}")
has_id "Books with no answers at all" "$B2" "as before"
eq "No answers recorded" "$(sql "select count(*) from booking_service_answers where booking_id='$(echo "$B2" | j id)'")" "0"

echo
echo "================ $PASS passed, $FAIL failed ================"
[ "$FAIL" -eq 0 ]
