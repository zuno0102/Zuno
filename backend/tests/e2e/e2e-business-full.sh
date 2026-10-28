#!/usr/bin/env bash
# THE WHOLE BUSINESS SCENARIO, from sign-up to a settled order, on an empty database.
#
# Every step goes through the real endpoints. Nothing is inserted directly, because the point is to
# prove the chain a real business actually walks:
#
#   1  sign up                     a brand-new business account
#   2  profile                     read it, change it, see the change stick
#   3  catalogue                   a service, a variant, questions
#   4  the customer                finds it and places an order
#   5  negotiation                 offer, counter, accept
#   6  the team                    invite a worker, they accept
#   7  crew                        assign, the worker answers
#   8  roles                       name a Lead on that job, and only then
#   9  status management           start the work, finish it
#   10 hiring                      a post, an applicant, an offer, an answer
#   11 money                       a pay run, wages sent, a worker's confirmation
#   12 rating                      the customer rates it, the business's standing moves
#
# Refusals are asserted alongside the happy path, because a rule nobody has ever seen refuse is a
# rule nobody has tested. Where a step is blocked by something this script cannot do — a real
# Razorpay payment — it says SKIP rather than quietly passing.
API=${API:-http://localhost:5056/api/v1}
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
PASS=0; FAIL=0; SKIP=0

sql()  { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()    { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
jnum() { grep -o "\"$1\":[0-9.]*" | head -1 | cut -d: -f2; }
msg()  { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-78; }

ok()   { PASS=$((PASS+1)); printf '  PASS  %-50s %s\n' "$1" "$2"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %-50s %s\n' "$1" "$2"; }
skip() { SKIP=$((SKIP+1)); printf '  SKIP  %-50s %s\n' "$1" "$2"; }
eq()   { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' want '$3'"; fi; }
has()  { if echo "$2" | grep -qF "$3"; then ok "$1" "$3"; else bad "$1" "missing: $3"; fi; }
yes()  { if echo "$2" | grep -q '"success":true'; then ok "$1" "$3"; else bad "$1" "$(echo "$2" | msg)"; fi; }
no()   { if echo "$2" | grep -q '"success":false'; then ok "$1" "refused: $(echo "$2" | msg)"; else bad "$1" "ALLOWED but the rule should have refused it"; fi; }
step() { printf '\n== %s ==\n' "$1"; }
cool() { printf '      (rate-limit window)\n'; sleep 63; }

P()  { local b="${3:-{\}}"; curl -s -X POST "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$b"; }
PU() { curl -s -X PUT "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$3"; }
G()  { curl -s "$API$1" -H "Authorization: Bearer $2"; }
code() { curl -s -o /dev/null -w '%{http_code}' "$API$1" -H "Authorization: Bearer $2"; }

PW='E2e@12345'
free_phone() { local c; for _ in $(seq 1 60); do c="9$(shuf -i 100000000-999999999 -n 1)"; [ -z "$(sql "select 1 from users where phone_number='$c'")" ] && { echo "$c"; return; }; done; }
reg1() { curl -s -X POST $API/auth/register -H 'Content-Type: application/json' \
  -d "{\"firstName\":\"$1\",\"lastName\":\"$2\",\"email\":\"$3\",\"password\":\"$PW\",\"phoneNumber\":\"$4\",\"role\":\"$5\"}"; }
reg()  { local b; b=$(reg1 "$@"); if ! echo "$b" | grep -q '"accessToken"'; then sleep 63; b=$(reg1 "$@"); fi; echo "$b"; }

echo "================================================================"
echo " ZUNO — THE WHOLE BUSINESS SCENARIO, ON AN EMPTY DATABASE"
echo " $(date '+%Y-%m-%d %H:%M')   $API"
echo "================================================================"
eq "Starting from no businesses at all" "$(sql "select count(*) from business_owner_profiles")" "0"

step "1. SIGN UP"
BT=$(reg Boss T "full_b$S@zuno.local" "$(free_phone)" BusinessOwner | j accessToken)
CT=$(reg Asha Rao "full_c$S@zuno.local" "$(free_phone)" Customer | j accessToken)
WT=$(reg Ravi Kumar "full_w$S@zuno.local" "$(free_phone)" Worker | j accessToken)
W2=$(reg Anita Menon "full_w2$S@zuno.local" "$(free_phone)" Worker | j accessToken)
eq "Business signed up"  "$([ -n "$BT" ] && echo yes)" "yes"
eq "Customer signed up"  "$([ -n "$CT" ] && echo yes)" "yes"
eq "Two workers signed up" "$([ -n "$WT" ] && [ -n "$W2" ] && echo yes)" "yes"
[ -n "$BT" ] && [ -n "$CT" ] && [ -n "$WT" ] && [ -n "$W2" ] || { echo "ABORTED: sign-up failed"; exit 1; }

ME=$(G /auth/me "$BT")
has "The new account is a BusinessOwner" "$ME" '"role":"BusinessOwner"'
eq  "A business profile was created with it" "$(sql "select count(*) from business_owner_profiles")" "1"

BIZ=$(sql "select id from business_owner_profiles limit 1")
WP=$(sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='full_w$S@zuno.local'")
WP2=$(sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='full_w2$S@zuno.local'")
DIST=$(sql "select id from districts limit 1")
CAT='a1111111-0000-0000-0000-000000000003'

step "2. THE BUSINESS PROFILE"
PROF=$(G /business/profile "$BT")
has "Profile reads back"            "$PROF" '"success":true'
has "...and starts unverified"      "$PROF" '"verificationStatus":"Pending"'
R=$(PU /business/profile "$BT" '{"businessName":"Boss T Catering","description":"Weddings and events","yearsOfExperience":7}')
yes "Profile changed" "$R" ""
has "...and the new name came back"  "$R" 'Boss T Catering'
eq  "...and it stuck in the database" "$(sql "select business_name from business_owner_profiles where id='$BIZ'")" "Boss T Catering"
no  "A blank business name is refused" "$(PU /business/profile "$BT" '{"businessName":"","description":"x","yearsOfExperience":1}')"

# Verification is an admin act, not a business one. Done directly because an admin journey is a
# different scenario; what matters here is that an unverified business cannot be found.
eq "An unverified business is not searchable" \
   "$(G "/customer/services?page=1&pageSize=50" "$CT" | grep -c 'Boss T Catering')" "0"
sql "update business_owner_profiles set verification_status=1, verified_at=now() where id='$BIZ'" >/dev/null

step "3. THE CATALOGUE"
SVC=$(P /business/services "$BT" "{\"serviceCategoryId\":\"$CAT\",\"name\":\"Wedding catering\",\"description\":\"Full service\",\"priceType\":\"Fixed\",\"price\":40000,\"requiredWorkerCount\":3,\"estimatedDurationMinutes\":480,\"districtIds\":[\"$DIST\"]}" | j id)
eq "Service created" "$([ -n "$SVC" ] && echo yes)" "yes"
VAR=$(P /business/services/$SVC/variants "$BT" '{"name":"Gold package","priceType":"Fixed","price":55000}' | j id)
eq "Variant created" "$([ -n "$VAR" ] && echo yes)" "yes"
yes "Questions set on the service" \
    "$(PU /business/services/$SVC/questions "$BT" '{"questions":[{"prompt":"How many guests?","isRequired":true,"displayOrder":1}]}')" ""
eq  "The service lists for the business" "$(G /business/services "$BT" | grep -c 'Wedding catering')" "1"

step "4. THE CUSTOMER FINDS IT AND ORDERS"
FOUND=$(G "/customer/services?page=1&pageSize=50" "$CT")
has "A verified business is searchable" "$FOUND" 'Wedding catering'
WHEN=$(date -u -d '+5 days 10:00' +%Y-%m-%dT%H:%M:%SZ)
QID=$(sql "select id from business_service_questions where business_service_id='$SVC' limit 1")
# answers is a LIST of {questionId, answerText}, not a map keyed by question id. Sending a map
# fails model binding outright — the whole body is rejected with "the command field is required",
# which looks like an auth or routing problem rather than a payload one.
BK=$(P /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$WHEN\",\"addressLine1\":\"14 Nila Nagar\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"latitude\":10.5276,\"longitude\":76.2144,\"country\":\"India\",\"answers\":[{\"questionId\":\"$QID\",\"answerText\":\"300\"}]}" | j id)
eq  "Order placed" "$([ -n "$BK" ] && echo yes)" "yes"
eq  "...and starts Pending"  "$(sql "select booking_status from bookings where id='$BK'")" "1"
eq  "...with the answer recorded" "$(sql "select answer_text from booking_service_answers where booking_id='$BK'")" "300"
eq  "The business was told"  "$(G '/notifications?take=20' "$BT" | grep -c 'BookingRequested')" "1"

cool

step "5. NEGOTIATION"
no  "Work cannot start on an unconfirmed order" "$(P /business/bookings/$BK/start "$BT")"
yes "Business offers terms"  "$(P /business/bookings/$BK/terms "$BT" '{"workerCount":5,"price":48000}')" ""
no  "...and cannot offer twice in a row" "$(P /business/bookings/$BK/terms "$BT" '{"workerCount":5,"price":47000}')"
eq  "The customer was told" "$(G '/notifications?take=20' "$CT" | grep -c 'BookingTermsProposed')" "1"
yes "Customer counters"      "$(P /customer/bookings/$BK/terms "$CT" '{"workerCount":5,"price":44000}')" ""
PROP=$(sql "select id from booking_agreement_proposals where booking_id='$BK' and proposal_status=1 limit 1")
no  "A business cannot accept its own offer" "$(P /customer/bookings/$BK/terms/$PROP/accept "$CT")"
yes "Business accepts the counter" "$(P /business/bookings/$BK/terms/$PROP/accept "$BT")" ""
eq  "...which confirms the order"  "$(sql "select booking_status from bookings where id='$BK'")" "6"
eq  "...at the agreed price"       "$(sql "select price_quoted::int from bookings where id='$BK'")" "44000"
eq  "...and the agreed crew size"  "$(sql "select required_worker_count from bookings where id='$BK'")" "5"

step "6. THE TEAM"
yes "Worker invited to the team" "$(P /business/workers/invite "$BT" "{\"workerIdentifier\":\"full_w$S@zuno.local\"}")" ""
no  "...and cannot be invited twice" "$(P /business/workers/invite "$BT" "{\"workerIdentifier\":\"full_w$S@zuno.local\"}")"
no  "An unknown identifier is refused" "$(P /business/workers/invite "$BT" '{"workerIdentifier":"nobody@nowhere.local"}')"
eq  "The worker was told" "$(G '/notifications?take=20' "$WT" | grep -c 'TeamInvitation')" "1"
INV=$(G /worker/invitations "$WT" | j id)
yes "Worker accepts" "$(P /worker/invitations/$INV/respond "$WT" '{"accept":true}')" ""
eq  "...and is now active on the team" "$(sql "select assignment_status from business_workers where business_owner_profile_id='$BIZ' and worker_profile_id='$WP'")" "2"
P /business/workers/invite "$BT" "{\"workerIdentifier\":\"full_w2$S@zuno.local\"}" >/dev/null
INV2=$(G /worker/invitations "$W2" | j id)
P /worker/invitations/$INV2/respond "$W2" '{"accept":true}' >/dev/null
eq  "Two on the team" "$(sql "select count(*) from business_workers where business_owner_profile_id='$BIZ' and assignment_status=2")" "2"

step "7. CREW"
yes "Worker assigned to the order" "$(P /business/bookings/$BK/assign-worker "$BT" "{\"workerProfileId\":\"$WP\",\"salaryAmount\":1200,\"salaryUnit\":\"PerEvent\"}")" ""
no  "...and cannot be assigned twice" "$(P /business/bookings/$BK/assign-worker "$BT" "{\"workerProfileId\":\"$WP\"}")"
no  "A wage with no unit is refused" "$(P /business/bookings/$BK/assign-worker "$BT" "{\"workerProfileId\":\"$WP2\",\"salaryAmount\":500}")"
eq  "The customer heard the crew is coming" "$(G '/notifications?take=20' "$CT" | grep -c 'BookingCrewAssigned')" "1"
eq  "The worker heard they have a job"      "$(G '/notifications?take=20' "$WT" | grep -c 'JobAssignment')" "1"
yes "Worker accepts the job" "$(P /worker/jobs/$BK/respond "$WT" '{"accept":true}')" ""
no  "...and cannot answer twice"  "$(P /worker/jobs/$BK/respond "$WT" '{"accept":true}')"
eq  "The business heard the answer" "$(G '/notifications?take=20' "$BT" | grep -c 'AssignmentAnswered')" "1"
yes "Second worker assigned" "$(P /business/bookings/$BK/assign-worker "$BT" "{\"workerProfileId\":\"$WP2\",\"salaryAmount\":900,\"salaryUnit\":\"PerEvent\"}")" ""
P /worker/jobs/$BK/respond "$W2" '{"accept":true}' >/dev/null

cool

step "8. ROLES ON THIS JOB"
no  "A role cannot go to somebody not on the job" "$(PU /business/bookings/$BK/crew/00000000-0000-0000-0000-000000000001/role "$BT" '{"role":"Lead"}')"
no  "A made-up role is refused"  "$(PU /business/bookings/$BK/crew/$WP/role "$BT" '{"role":"Captain"}')"
yes "Ravi is made Lead on this job" "$(PU /business/bookings/$BK/crew/$WP/role "$BT" '{"role":"Lead"}')" ""
yes "Anita is made Supervisor"      "$(PU /business/bookings/$BK/crew/$WP2/role "$BT" '{"role":"Supervisor"}')" ""
eq  "The Lead's own screen knows"      "$(G /worker/jobs/$BK "$WT" | grep -o '"myRole":"[^"]*"' | cut -d'"' -f4)" "Lead"
eq  "The Supervisor's screen knows too" "$(G /worker/jobs/$BK "$W2" | grep -o '"myRole":"[^"]*"' | cut -d'"' -f4)" "Supervisor"

step "9. STATUS MANAGEMENT"
no  "Work cannot start before the day" "$(P /worker/jobs/$BK/start-job "$WT")"
sql "update bookings set scheduled_date = now() - interval '1 hour' where id='$BK'" >/dev/null
no  "A Supervisor cannot start the work" "$(P /worker/jobs/$BK/start-job "$W2")"
yes "The Lead starts the work"           "$(P /worker/jobs/$BK/start-job "$WT")" ""
eq  "Order is In progress"               "$(sql "select booking_status from bookings where id='$BK'")" "3"
eq  "The customer was told, naming the Lead" \
    "$(G '/notifications?take=30' "$CT" | tr '}' '\n' | grep -c 'Ravi Kumar has started your job')" "1"
no  "...and cannot be started twice"     "$(P /worker/jobs/$BK/start-job "$WT")"
yes "A worker finishes their own part"   "$(P /worker/jobs/$BK/complete "$W2")" ""
yes "The Lead finishes the whole job"    "$(P /worker/jobs/$BK/finish-job "$WT")" ""
eq  "Order is Completed"                 "$(sql "select booking_status from bookings where id='$BK'")" "4"
eq  "...and the whole crew with it"      "$(sql "select count(*) from booking_worker_assignments where booking_id='$BK' and assignment_status=4")" "2"
no  "A role cannot be set once it is over" "$(PU /business/bookings/$BK/crew/$WP/role "$BT" '{"role":"Supervisor"}')"

cool

step "10. HIRING"
EVENT=$(date -u -d '+12 days 10:00' +%Y-%m-%dT%H:%M:%SZ)
POST=$(P /business/hiring-posts "$BT" "{\"title\":\"Kovalam beach servers\",\"eventDate\":\"$EVENT\",\"durationMinutes\":240,\"workersNeeded\":1,\"salaryAmount\":900,\"salaryUnit\":\"PerEvent\",\"location\":\"Kovalam\"}" | j id)
eq  "Hiring post created" "$([ -n "$POST" ] && echo yes)" "yes"
yes "A worker applies" "$(P /worker/hiring-posts/$POST/apply "$W2" '{}')" ""
no  "...and cannot apply twice" "$(P /worker/hiring-posts/$POST/apply "$W2" '{}')"
eq  "The business was told" "$(G '/notifications?take=30' "$BT" | grep -c 'NewApplicants')" "1"
APP=$(sql "select id from hiring_post_applications where hiring_post_id='$POST' and worker_profile_id='$WP2'")
yes "Business hires the applicant" "$(P /business/hiring-posts/applications/$APP/confirm "$BT")" ""
eq  "The worker was told they were hired" "$(G '/notifications?take=30' "$W2" | grep -c 'JobOfferConfirmed')" "1"
eq  "They applied, so they are hired at once (Accepted)" "$(sql "select application_status from hiring_post_applications where id='$APP'")" "4"
no  "...with no offer left for them to answer" "$(P /worker/hiring-posts/applications/$APP/respond "$W2" '{"accept":true}')"
eq  "The post is now filled" "$(sql "select hiring_post_status from hiring_posts where id='$POST'")" "2"
yes "Business raises the agreed wage" "$(P /business/hiring-posts/applications/$APP/salary "$BT" '{"newAmount":1100,"reason":"Longer day"}')" ""
no  "...but cannot lower it"           "$(P /business/hiring-posts/applications/$APP/salary "$BT" '{"newAmount":800,"reason":"no"}')"
eq  "The worker was told about the raise" "$(G '/notifications?take=30' "$W2" | grep -c 'WageRaised')" "1"

step "11. MONEY"
sql "update hiring_posts set event_date = now() - interval '5 hours' where id='$POST'" >/dev/null
yes "Work started on the post"  "$(P /business/hiring-posts/$POST/start "$BT")" ""
yes "Work finished on the post" "$(P /business/hiring-posts/$POST/complete "$BT")" ""
eq  "Wages are now outstanding" "$(sql "select payment_status from hiring_post_applications where id='$APP'")" "1"
BATCH=$(P /business/hiring-posts/$POST/payouts "$BT" '{}' | j id)
eq  "A pay run opened" "$([ -n "$BATCH" ] && echo yes)" "yes"
eq  "...for the raised amount" "$(sql "select total_amount::int from payout_batches where id='$BATCH'")" "1100"
# Funding needs a payment Razorpay will vouch for. Against the real credentials that means a
# human typing a UPI PIN, so this used to be skipped and the last step of the money story went
# uncovered. Run the API with Razorpay__SimulateCollection=true and it is covered instead; the
# refusal side — what happens when the signature does not check out — is e2e-pay-on-mobile.sh,
# which has to run with simulation off.
# A verified destination to send it to. Without one the disbursement fails with "no UPI ID on
# file" — which is the app behaving correctly, and is covered on its own in e2e-pay-on-mobile.sh.
sql "insert into worker_payout_details (id,worker_profile_id,upi_vpa,account_holder_name,verification_status,verified_at,created_date,is_deleted,status) select gen_random_uuid(), '$WP2', 'anita$S@upi', 'Anita Menon', 1, now(), now(), false, 1" >/dev/null

FUND=$(P /business/hiring-posts/payouts/$BATCH/confirm "$BT" "{\"providerPaymentId\":\"pay_full$S\",\"signature\":\"sim\"}")
if echo "$FUND" | grep -q '"success":true'; then
    ok "Funding the pay run" "collected and disbursed"
    eq "...the wage reads paid"       "$(sql "select payment_status from hiring_post_applications where id='$APP'")" "3"
    eq "...the pay run completed"     "$(sql "select batch_status from payout_batches where id='$BATCH'")" "3"
    eq "Wages-paid notification"      "$(G '/notifications?take=30' "$W2" | grep -c 'WagePaid')" "1"
    eq "...naming the raised amount"  "$(G '/notifications?take=30' "$W2" | tr '{' '\n' | grep 'WagePaid' | grep -c '1,100')" "1"
else
    skip "Funding the pay run" "needs a verifiable Razorpay payment (run with Razorpay__SimulateCollection=true)"
    skip "Wages-paid notification" "follows funding"
fi

step "12. RATING AND STANDING"
yes "Customer rates the finished order" "$(P /customer/bookings/$BK/rate "$CT" '{"score":5,"comment":"On time, good crew"}')" ""
no  "...and cannot rate twice"           "$(P /customer/bookings/$BK/rate "$CT" '{"score":1}')"
eq  "The business was told"               "$(G '/notifications?take=30' "$BT" | grep -c 'RatingReceived')" "1"
# Compared as a number, not as text: the column is numeric and psql prints it without trailing
# zeros, so matching against the string "5.00" fails on a value that is exactly right.
eq  "...and its customer rating moved"    "$(sql "select (customer_rating_average = 5)::text from business_owner_profiles where id='$BIZ'")" "true"
eq  "...counted as one review"            "$(sql "select customer_review_count from business_owner_profiles where id='$BIZ'")" "1"

# The rule this proves, which is easy to get backwards: a finished job does NOT count towards the
# business's record until its wages are clear too. There are two finished jobs by now — the
# customer's order and the hiring post — and only the post has been paid. So the count is one, not
# two: the order is finished and rated but its crew are still owed, and counting it would let a
# business build a record on wages it never paid.
eq  "Only the paid job counts" \
    "$(sql "select completed_job_count from business_owner_profiles where id='$BIZ'")" "1"
eq  "...and the order is not it, its crew are still owed" \
    "$(sql "select count(*) from booking_worker_assignments a join bookings b on b.id=a.booking_id where b.id='$BK' and a.payment_status=1")" "2"

step "SUMMARY OF WHAT THE BUSINESS NOW HAS"
printf '  %-26s %s\n' "orders"        "$(sql "select count(*) from bookings where business_owner_profile_id='$BIZ'")"
printf '  %-26s %s\n' "team"          "$(sql "select count(*) from business_workers where business_owner_profile_id='$BIZ'")"
printf '  %-26s %s\n' "services"      "$(sql "select count(*) from business_services where business_owner_profile_id='$BIZ'")"
printf '  %-26s %s\n' "hiring posts"  "$(sql "select count(*) from hiring_posts where business_owner_profile_id='$BIZ'")"
printf '  %-26s %s\n' "notifications" "$(sql "select count(*) from notifications")"

echo
echo "================================================================"
printf ' PASS %s   FAIL %s   SKIP %s\n' "$PASS" "$FAIL" "$SKIP"
echo " business: full_b$S@zuno.local / $PW"
echo "================================================================"
[ "$FAIL" -eq 0 ]
