#!/usr/bin/env bash
# Test data for checking the crew-strength flow on the phone.
#
# Builds one catering business priced by the head, with its own questions, and FOUR orders — one
# at each stage of agreeing how many people the job takes. You can then open the app and see what
# each stage looks like without having to drive the API yourself.
#
#   Order 1   nobody has offered yet          "₹500 per person · crew size to be agreed"
#   Order 2   business offered 20             waiting on the customer
#   Order 3   customer countered 18           waiting on the business
#   Order 4   business accepted 18            CONFIRMED · ₹9,000 · 18 people
#
# Re-runnable: every run makes its own business and customer, so nothing collides.
API=http://localhost:5056/api/v1
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
PW='Crew@12345'

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }

reg() {
  local body
  body=$(curl -s -X POST $API/auth/register -H 'Content-Type: application/json' \
    -d "{\"firstName\":\"$1\",\"lastName\":\"$2\",\"email\":\"$3\",\"password\":\"$PW\",\"phoneNumber\":\"9$((RANDOM%900000000+100000000))\",\"role\":\"$4\"}")
  if ! echo "$body" | grep -q '"accessToken"'; then
    # Registration is rate limited to 5 a minute per IP. Waiting it out beats failing.
    echo "   (waiting out the auth rate limit...)" >&2
    sleep 62
    body=$(curl -s -X POST $API/auth/register -H 'Content-Type: application/json' \
      -d "{\"firstName\":\"$1\",\"lastName\":\"$2\",\"email\":\"$3\",\"password\":\"$PW\",\"phoneNumber\":\"9$((RANDOM%900000000+100000000))\",\"role\":\"$4\"}")
  fi
  echo "$body"
}
post_() { curl -s -X POST "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "${3:-\{\}}"; }
put_()  { curl -s -X PUT  "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "${3:-\{\}}"; }

BIZ_EMAIL="crew_b$S@zuno.local"
CUST_EMAIL="crew_c$S@zuno.local"

echo "Creating the business and customer..."
BT=$(reg Sunil Caterers "$BIZ_EMAIL" BusinessOwner | j accessToken)
CT=$(reg Divya Menon "$CUST_EMAIL" Customer | j accessToken)
if [ -z "$BT" ] || [ -z "$CT" ]; then echo "registration failed"; exit 1; fi

# Visible to customers, which a business is not until someone approves it.
sql "update business_owner_profiles set verification_status=1, verified_at=now(), business_name='Sunil Caterers' where user_id=(select id from users where email='$BIZ_EMAIL')" >/dev/null

CAT=$(sql "select id from service_categories where slug='cleaning' and is_deleted=false")
DIST=$(sql "select id from districts where is_deleted=false limit 1")

echo "Creating a per-person catering service..."
SVC=$(post_ /business/services "$BT" "{\"serviceCategoryId\":\"$CAT\",\"name\":\"Wedding catering\",\"description\":\"Full service catering, priced by the head\",\"priceType\":\"PerPerson\",\"price\":500,\"requiredWorkerCount\":0,\"districtIds\":[\"$DIST\"]}" | j id)

echo "Adding the questions it asks..."
put_ "/business/services/$SVC/questions" "$BT" '{"questions":[
  {"prompt":"Enter your dishes count","isRequired":true},
  {"prompt":"Enter your items","isRequired":true},
  {"prompt":"Total serving items","isRequired":false}]}' >/dev/null

book() { # scheduledOffsetDays dishes items serving
  local when
  when=$(date -u -d "+$1 days 11:00" +%Y-%m-%dT%H:%M:%SZ)
  local q1 q2 q3
  q1=$(sql "select id from business_service_questions where business_service_id='$SVC' and sort_order=0 and is_deleted=false")
  q2=$(sql "select id from business_service_questions where business_service_id='$SVC' and sort_order=1 and is_deleted=false")
  q3=$(sql "select id from business_service_questions where business_service_id='$SVC' and sort_order=2 and is_deleted=false")
  post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$when\",\"addressLine1\":\"$5\",\"city\":\"Kochi\",\"state\":\"Kerala\",\"postalCode\":\"682001\",\"answers\":[
    {\"questionId\":\"$q1\",\"answerText\":\"$2\"},
    {\"questionId\":\"$q2\",\"answerText\":\"$3\"},
    {\"questionId\":\"$q3\",\"answerText\":\"$4\"}]}" | j id
}

echo "Placing four orders, one at each stage..."

B1=$(book 12 "8"  "biryani, chicken curry, payasam"            "150" "Kalathil Auditorium")
B2=$(book 18 "12" "biryani, paneer, gulab jamun, salad"        "400" "Grand Hyatt Bolgatty")
B3=$(book 25 "10" "veg meals, sambar, avial, payasam"          "300" "Kadavanthra Hall")
B4=$(book 32 "14" "biryani, fish fry, prawns, gulab jamun"     "500" "Le Meridien Kochi")

# 2: the business has offered and is waiting on the customer.
post_ "/business/bookings/$B2/terms" "$BT" \
  '{"workerCount":20,"price":10000,"message":"400 guests needs 5 servers per 100"}' >/dev/null

# 3: the customer has countered and it is back with the business.
post_ "/business/bookings/$B3/terms" "$BT" \
  '{"workerCount":16,"price":8000,"message":"300 guests, 16 covers it comfortably"}' >/dev/null
post_ "/customer/bookings/$B3/terms" "$CT" \
  '{"workerCount":14,"price":7000,"message":"our family will help serve, 14 is enough"}' >/dev/null

# 4: agreed and confirmed — the business came down from 20 to 18.
post_ "/business/bookings/$B4/terms" "$BT" \
  '{"workerCount":20,"price":10000,"message":"500 guests, we recommend 20"}' >/dev/null
post_ "/customer/bookings/$B4/terms" "$CT" \
  '{"workerCount":18,"price":9000,"message":"18 is enough, we have 2 of our own"}' >/dev/null
P4=$(sql "select id from booking_agreement_proposals where booking_id='$B4' and proposal_status=1 and is_deleted=false")
post_ "/business/bookings/$B4/terms/$P4/accept" "$BT" >/dev/null

echo
echo "================================ READY ================================"
echo
echo "  BUSINESS   $BIZ_EMAIL"
echo "  CUSTOMER   $CUST_EMAIL"
echo "  PASSWORD   $PW    (both)"
echo
printf '  %-38s %s\n' "ORDER" "CREW STRENGTH"
printf '  %-38s %s\n' "-----" "-------------"
for pair in "$B1:150 guests, 8 dishes" "$B2:400 guests, 12 dishes" "$B3:300 guests, 10 dishes" "$B4:500 guests, 14 dishes"; do
  id="${pair%%:*}"; label="${pair#*:}"
  ref=$(sql "select booking_status from bookings where id='$id'")
  crew=$(sql "select required_worker_count from bookings where id='$id'")
  price=$(sql "select price_quoted from bookings where id='$id'")
  rounds=$(sql "select count(*) from booking_agreement_proposals where booking_id='$id'")
  openby=$(sql "select case proposed_by_role when 2 then 'business offered' when 1 then 'customer countered' end from booking_agreement_proposals where booking_id='$id' and proposal_status=1 and is_deleted=false")
  state=$([ "$ref" = "6" ] && echo "CONFIRMED" || echo "Pending")
  printf '  %-38s %s\n' "$label" "$state · crew $crew · ₹$price · $rounds round(s) ${openby:+· $openby, awaiting reply}"
done
echo
echo "  What to look for in the app:"
echo "    150 guests  — no offer yet, reads '₹500 per person · crew size to be agreed'"
echo "    400 guests  — business offered 20, waiting on the customer"
echo "    300 guests  — customer countered 14, back with the business"
echo "    500 guests  — agreed at 18, reads '₹9,000 · 18 people', order CONFIRMED"
echo
echo "  Every order also carries the customer's answers: dishes count, items, servings."
echo "======================================================================="
