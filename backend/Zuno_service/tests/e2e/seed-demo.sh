#!/usr/bin/env bash
# Demo data for trying every screen by hand: one business, one customer and a crew of workers, with
# orders, hiring posts and full-time jobs in every state the app can show.
#
# Everything is created through the real API — sign-up, admin approval, orders, offers, hiring,
# pay runs, ratings — so what you see on screen took the same path a real user's data would. The only
# direct writes move an order's or post's date into the past, because "the job has started" cannot
# be reached any other way without waiting for the day.
#
# Run against a LOCAL API started with simulated payments and raised rate limits:
#   Razorpay__SimulateCollection=true RateLimiting__Auth__PermitLimit=500 \
#     dotnet run --project Zuno_service/src/Zuno.Api --launch-profile http
#   PGPASSWORD=... PSQL="/c/Program Files/PostgreSQL/16/bin/psql.exe" bash seed-demo.sh
#
# Safe to run again: existing demo accounts are signed in to, and a section whose data is already
# there (services, orders, hiring posts, full-time jobs) is skipped, so a second run only fills gaps.

API=${API:-http://localhost:5056/api/v1}
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
PW='Demo@1234'
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@zuno.local}
ADMIN_PW=${ADMIN_PW:-Admin@12345}

sql()  { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()    { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
P()    { local b="${3:-{\}}"; curl -s -X POST "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$b"; }
PU()   { curl -s -X PUT "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$3"; }
G()    { curl -s "$API$1" -H "Authorization: Bearer $2"; }
OK=0; BAD=0
did()  { if echo "$2" | grep -q '"success":true'; then OK=$((OK+1)); printf '  ok    %s\n' "$1"; else BAD=$((BAD+1)); printf '  FAIL  %s  %s\n' "$1" "$(echo "$2" | tr ',' '\n' | grep -m1 '"message"' | cut -d'"' -f4 | cut -c1-90)"; fi; }
got()  { if [ -n "$2" ]; then OK=$((OK+1)); printf '  ok    %s\n' "$1"; else BAD=$((BAD+1)); printf '  FAIL  %s\n' "$1"; fi; }
step() { printf '\n== %s ==\n' "$1"; }
free_phone() { local c; for _ in $(seq 1 60); do c="9$(shuf -i 100000000-999999999 -n 1)"; [ -z "$(sql "select 1 from users where phone_number='$c'")" ] && { echo "$c"; return; }; done; }
reg()  { if [ -n "$(sql "select 1 from users where email='$3'")" ]; then login "$3" "$PW"; return; fi
         curl -s -X POST $API/auth/register -H 'Content-Type: application/json' \
           -d "{\"firstName\":\"$1\",\"lastName\":\"$2\",\"email\":\"$3\",\"password\":\"$PW\",\"phoneNumber\":\"$(free_phone)\",\"role\":\"$4\"}" | j accessToken; }
login(){ curl -s -X POST $API/auth/login -H 'Content-Type: application/json' -d "{\"emailOrPhone\":\"$1\",\"password\":\"$2\"}" | j accessToken; }
wp()   { sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='$1'"; }
past() { sql "update bookings set scheduled_date = now() - interval '$2' where id='$1'" >/dev/null; }
when() { date -u -d "$1" +%Y-%m-%dT%H:%M:%SZ; }

logins() {
  echo
  echo "================================================================"
  echo " DEMO LOGINS (password for all: $PW)"
  echo "   Business : demo.business@zuno.local   (Meera, 'Demo Events & Catering')"
  echo "   Customer : demo.customer@zuno.local   (Asha)"
  echo "   Worker   : demo.worker@zuno.local     (Ravi — Lead, has UPI)"
  echo "   Workers  : demo.worker2@zuno.local (Anita, paid)  demo.worker3@zuno.local (Kumar, no UPI)"
  echo "              demo.worker4@zuno.local (Divya, invitation waiting)"
  echo "   Admin    : $ADMIN_EMAIL / $ADMIN_PW"
  echo "================================================================"
}


step "1. ACCOUNTS"
BT=$(reg Meera Nair demo.business@zuno.local BusinessOwner);  got "Business  demo.business"  "$BT"
CT=$(reg Asha Rao demo.customer@zuno.local Customer);         got "Customer  demo.customer"  "$CT"
WT=$(reg Ravi Kumar demo.worker@zuno.local Worker);           got "Worker    demo.worker"    "$WT"
W2=$(reg Anita Menon demo.worker2@zuno.local Worker);         got "Worker    demo.worker2"   "$W2"
W3=$(reg Kumar Das demo.worker3@zuno.local Worker);           got "Worker    demo.worker3"   "$W3"
W4=$(reg Divya Pillai demo.worker4@zuno.local Worker);        got "Worker    demo.worker4"   "$W4"
[ -n "$BT" ] && [ -n "$CT" ] && [ -n "$WT" ] && [ -n "$W2" ] && [ -n "$W3" ] && [ -n "$W4" ] \
  || { echo "ABORTED: sign-up failed (rate limit? start the API with RateLimiting__Auth__PermitLimit=500)"; exit 1; }
WP1=$(wp demo.worker@zuno.local); WP2=$(wp demo.worker2@zuno.local); WP3=$(wp demo.worker3@zuno.local)
BIZ=$(sql "select b.id from business_owner_profiles b join users u on u.id=b.user_id where u.email='demo.business@zuno.local'")

step "2. BUSINESS PROFILE AND ADMIN APPROVAL"
have() { [ "$(sql "$1")" != "0" ]; }
did "Profile filled in" "$(PU /business/profile "$BT" '{"businessName":"Demo Events & Catering","description":"Weddings, parties and office events in Kerala","upiId":"demo.events@okhdfcbank"}')"
AT=$(login "$ADMIN_EMAIL" "$ADMIN_PW")
if have "select count(*) from business_owner_profiles where id='$BIZ' and verification_status=1"; then echo "  --    already approved"
elif [ -n "$AT" ]; then did "Admin approves the business" "$(P /admin/businesses/$BIZ/approve "$AT")"
else sql "update business_owner_profiles set verification_status=1, verified_at=now() where id='$BIZ'" >/dev/null; echo "  ok    Approved directly (admin login not available)"; fi

step "3. SERVICES"
DIST=$(sql "select id from districts where name ilike 'Thrissur' limit 1"); [ -z "$DIST" ] && DIST=$(sql "select id from districts limit 1")
CAT=$(sql "select id from service_categories where not is_deleted and is_active and name ilike '%cater%' limit 1")
[ -z "$CAT" ] && CAT=$(sql "select id from service_categories where not is_deleted and is_active order by name limit 1")
svc_id() { sql "select id from business_services where business_owner_profile_id='$BIZ' and name='$1' and not is_deleted limit 1"; }
if have "select count(*) from business_services where business_owner_profile_id='$BIZ' and not is_deleted"; then
  SVC=$(svc_id 'Wedding catering'); SVC2=$(svc_id 'Event cleaning'); echo "  --    services already there"
else
SVC=$(P /business/services "$BT" "{\"serviceCategoryId\":\"$CAT\",\"name\":\"Wedding catering\",\"description\":\"Full service for 100-500 guests\",\"priceType\":\"Fixed\",\"price\":40000,\"requiredWorkerCount\":3,\"estimatedDurationMinutes\":480,\"districtIds\":[\"$DIST\"]}" | j id)
got "Service: Wedding catering (fixed price)" "$SVC"
did "...with a package: Gold" "$(P /business/services/$SVC/variants "$BT" '{"name":"Gold package","priceType":"Fixed","price":55000}')"
did "...and a question for customers" "$(PU /business/services/$SVC/questions "$BT" '{"questions":[{"prompt":"How many guests?","isRequired":true,"displayOrder":1}]}')"
SVC2=$(P /business/services "$BT" "{\"serviceCategoryId\":\"$CAT\",\"name\":\"Event cleaning\",\"description\":\"Before and after your event\",\"priceType\":\"Hourly\",\"price\":600,\"requiredWorkerCount\":2,\"estimatedDurationMinutes\":180,\"districtIds\":[\"$DIST\"]}" | j id)
got "Service: Event cleaning (hourly)" "$SVC2"
fi
QID=$(sql "select id from business_service_questions where business_service_id='$SVC' limit 1")

step "4. TEAM AND PAYOUT DETAILS"
for pair in "demo.worker@zuno.local:$WT" "demo.worker2@zuno.local:$W2" "demo.worker3@zuno.local:$W3"; do
  email=${pair%%:*}; tok=${pair#*:}
  if have "select count(*) from business_workers b join worker_profiles w on w.id=b.worker_profile_id join users u on u.id=w.user_id where b.business_owner_profile_id='$BIZ' and u.email='$email' and b.assignment_status=2"; then echo "  --    $email already on the team"; continue; fi
  P /business/workers/invite "$BT" "{\"workerIdentifier\":\"$email\"}" >/dev/null
  did "$email joins the team" "$(P /worker/invitations/$(G /worker/invitations "$tok" | j id)/respond "$tok" '{"accept":true}')"
done
have "select count(*) from business_workers b join worker_profiles w on w.id=b.worker_profile_id join users u on u.id=w.user_id where b.business_owner_profile_id='$BIZ' and u.email='demo.worker4@zuno.local'" && echo "  --    demo.worker4 already invited" || did "demo.worker4 invited (left waiting for an answer)" "$(P /business/workers/invite "$BT" '{"workerIdentifier":"demo.worker4@zuno.local"}')"
did "Ravi adds a UPI ID (ready to be paid)"  "$(PU /worker/profile "$WT" '{"upiVpa":"ravi.demo@okaxis"}')"
did "Anita adds a UPI ID (ready to be paid)" "$(PU /worker/profile "$W2" '{"upiVpa":"anita.demo@ybl"}')"
echo "  --    Kumar has no UPI ID (shows 'No UPI ID on file' to the business)"

step "5. ORDERS — ONE IN EVERY STATE"
if have "select count(*) from bookings where business_owner_profile_id='$BIZ'"; then echo "  --    orders already there"; else
# Only the catering service asks a question; an answer sent to a service that asks none is refused.
order() { local s="${2:-$SVC}" a=""; [ "$s" = "$SVC" ] && a=",\"answers\":[{\"questionId\":\"$QID\",\"answerText\":\"${3:-200}\"}]"
  P /customer/bookings "$CT" "{\"businessServiceId\":\"$s\",\"scheduledDate\":\"$1\",\"addressLine1\":\"14 Nila Nagar\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"latitude\":10.5276,\"longitude\":76.2144,\"country\":\"India\"$a}" | j id; }
B1=$(order "$(when '+6 days 11:00')");          got "1 New request (waiting for the business)" "$B1"
B2=$(order "$(when '+9 days 12:00')");          got "2 Terms offered (waiting for the customer)" "$B2"
did "   business offers 5 workers for Rs 48,000" "$(P /business/bookings/$B2/terms "$BT" '{"workerCount":5,"price":48000}')"
B3=$(order "$(when '+12 days 10:00')" "" 350);  got "3 Confirmed, crew being put together" "$B3"
did "   business confirms" "$(P /business/bookings/$B3/confirm "$BT")"
did "   Ravi assigned (Rs 1,200)" "$(P /business/bookings/$B3/assign-worker "$BT" "{\"workerProfileId\":\"$WP1\",\"salaryAmount\":1200,\"salaryUnit\":\"PerEvent\"}")"
did "   Ravi accepts" "$(P /worker/jobs/$B3/respond "$WT" '{"accept":true}')"
did "   Ravi made Lead" "$(PU /business/bookings/$B3/crew/$WP1/role "$BT" '{"role":"Lead"}')"
did "   Kumar assigned and accepts (no UPI yet)" "$(P /business/bookings/$B3/assign-worker "$BT" "{\"workerProfileId\":\"$WP3\",\"salaryAmount\":900,\"salaryUnit\":\"PerEvent\"}")"
P /worker/jobs/$B3/respond "$W3" '{"accept":true}' >/dev/null
did "   Anita assigned (offer waiting for her answer)" "$(P /business/bookings/$B3/assign-worker "$BT" "{\"workerProfileId\":\"$WP2\",\"salaryAmount\":1000,\"salaryUnit\":\"PerEvent\"}")"
did "   customer asks a question in chat" "$(P /bookings/$B3/messages "$CT" '{"body":"Can you bring extra plates for 50 more guests?"}')"
did "   business replies" "$(P /bookings/$B3/messages "$BT" '{"body":"Yes, no extra charge. See you on the day!"}')"
B4=$(order "$(when '+2 days 09:00')" "$SVC2");  got "4 In progress (work started, Kumar leads)" "$B4"
P /business/bookings/$B4/confirm "$BT" >/dev/null
P /business/bookings/$B4/assign-worker "$BT" "{\"workerProfileId\":\"$WP3\",\"salaryAmount\":800,\"salaryUnit\":\"PerEvent\"}" >/dev/null
P /worker/jobs/$B4/respond "$W3" '{"accept":true}' >/dev/null
PU /business/bookings/$B4/crew/$WP3/role "$BT" '{"role":"Lead"}' >/dev/null
past "$B4" '2 hours'
# Kumar, not Ravi: a worker on a job in progress is busy, and Ravi is needed free for the hiring posts.
did "   Kumar (Lead) starts the work" "$(P /worker/jobs/$B4/start-job "$W3")"
B5=$(order "$(when '+3 days 10:00')");          got "5 Completed and rated 5 stars" "$B5"
P /business/bookings/$B5/confirm "$BT" >/dev/null
P /business/bookings/$B5/assign-worker "$BT" "{\"workerProfileId\":\"$WP2\",\"salaryAmount\":1000,\"salaryUnit\":\"PerEvent\"}" >/dev/null
P /worker/jobs/$B5/respond "$W2" '{"accept":true}' >/dev/null
PU /business/bookings/$B5/crew/$WP2/role "$BT" '{"role":"Lead"}' >/dev/null
past "$B5" '3 days'
P /worker/jobs/$B5/start-job "$W2" >/dev/null
did "   Anita finishes the job" "$(P /worker/jobs/$B5/finish-job "$W2")"
did "   customer rates it 5 stars" "$(P /customer/bookings/$B5/rate "$CT" '{"score":5,"comment":"Excellent food and a very polite crew"}')"
B6=$(order "$(when '+4 days 10:00')" "$SVC2");  got "6 Completed, not rated yet (customer can rate)" "$B6"
P /business/bookings/$B6/confirm "$BT" >/dev/null
P /business/bookings/$B6/assign-worker "$BT" "{\"workerProfileId\":\"$WP2\",\"salaryAmount\":700,\"salaryUnit\":\"PerEvent\"}" >/dev/null
P /worker/jobs/$B6/respond "$W2" '{"accept":true}' >/dev/null
past "$B6" '1 day'
did "   business starts and finishes it" "$(P /business/bookings/$B6/start "$BT" >/dev/null; P /business/bookings/$B6/complete "$BT")"
B7=$(order "$(when '+20 days 10:00')");         got "7 Cancelled by the customer" "$B7"
did "   customer cancels with a reason" "$(P /customer/bookings/$B7/cancel "$CT" '{"reason":"Event date moved to next month"}')"
fi

step "6. HIRING POSTS — ONE IN EVERY STATE"
if have "select count(*) from hiring_posts where business_owner_profile_id='$BIZ'"; then echo "  --    hiring posts already there"; else
post() { P /business/hiring-posts "$BT" "{\"title\":\"$1\",\"eventDate\":\"$2\",\"durationMinutes\":240,\"workersNeeded\":${3:-2},\"salaryAmount\":${4:-900},\"salaryUnit\":\"PerEvent\",\"location\":\"Thrissur town hall\",\"latitude\":10.5276,\"longitude\":76.2144}" | j id; }
app()  { sql "select id from hiring_post_applications where hiring_post_id='$1' and worker_profile_id='$2'"; }
H1=$(post "Wedding servers needed" "$(when '+15 days 10:00')");    got "1 Open, with a new applicant (Kumar)" "$H1"
did "   Kumar applies" "$(P /worker/hiring-posts/$H1/apply "$W3" '{}')"
H2=$(post "Stage helpers for a concert" "$(when '+18 days 16:00')" 1 1100); got "2 Job offer sent to Ravi (he can accept or decline)" "$H2"
did "   business invites Ravi" "$(P /business/hiring-posts/$H2/invite "$BT" '{"workerIdentifier":"demo.worker@zuno.local"}')"
H3=$(post "Birthday party crew" "$(when '+5 days 17:00')" 1 1000); got "3 Done and PAID (Anita)" "$H3"
P /worker/hiring-posts/$H3/apply "$W2" '{}' >/dev/null
did "   business hires Anita" "$(P /business/hiring-posts/applications/$(app $H3 $WP2)/confirm "$BT")"
sql "update hiring_posts set event_date = now() - interval '6 hours' where id='$H3'" >/dev/null
P /business/hiring-posts/$H3/start "$BT" >/dev/null; P /business/hiring-posts/$H3/complete "$BT" >/dev/null
BATCH=$(P /business/hiring-posts/$H3/payouts "$BT" '{}' | j id)
did "   pay run funded and wages sent (simulated payment)" "$(P /business/hiring-posts/payouts/$BATCH/confirm "$BT" "{\"providerPaymentId\":\"pay_demo_$(date +%s)\",\"signature\":\"sim\"}")"
H4=$(post "Office party crew" "$(when '+6 days 18:00')" 1 1200); got "4 Done, wages waiting to be paid (Ravi)" "$H4"
P /worker/hiring-posts/$H4/apply "$WT" '{}' >/dev/null
P /business/hiring-posts/applications/$(app $H4 $WP1)/confirm "$BT" >/dev/null
sql "update hiring_posts set event_date = now() - interval '5 hours' where id='$H4'" >/dev/null
P /business/hiring-posts/$H4/start "$BT" >/dev/null
did "   work finished, Pay crew button now shown" "$(P /business/hiring-posts/$H4/complete "$BT")"
H5=$(post "Temple festival volunteers" "$(when '+25 days 08:00')" 3 700); got "5 Hiring stopped" "$H5"
did "   business stops hiring" "$(P /business/hiring-posts/$H5/stop-hiring "$BT")"
fi

step "7. FULL-TIME JOBS"
if have "select count(*) from vacancies where business_owner_profile_id='$BIZ'"; then echo "  --    full-time jobs already there"; else
FULLTIME=$(sql "select id from vacancy_job_types where name='Full-time'")
REQS='[{"kind":"File","prompt":"Resume","isRequired":true},{"kind":"Text","prompt":"Which area do you live in?","isRequired":true},{"kind":"YesNo","prompt":"Do you have a two-wheeler?","isRequired":false}]'
V1=$(P /business/vacancies "$BT" "{\"title\":\"Shop receptionist\",\"jobTypeId\":\"$FULLTIME\",\"openings\":2,\"salaryMin\":15000,\"salaryMax\":20000,\"payPeriod\":\"PerMonth\",\"workingDaysPerWeek\":6,\"shiftStart\":\"09:30:00\",\"shiftEnd\":\"18:00:00\",\"location\":\"Round North, Thrissur\",\"latitude\":10.5276,\"longitude\":76.2144,\"requirements\":$REQS}" | j id)
got "1 Live job post with applicants" "$V1"
P /business/vacancies/$V1/payment "$BT" >/dev/null
did "   Rs 49 listing fee paid (simulated)" "$(P /business/vacancies/$V1/payment/confirm "$BT" '{"providerPaymentId":"sim_demo_pay"}')"
TMP=$(mktemp -d); printf '%%PDF-1.4\n%% resume\n' > "$TMP/resume.pdf"
RQ_FILE=$(sql "select id from vacancy_requirements where vacancy_id='$V1' and sort_order=0 and not is_deleted")
RQ_AREA=$(sql "select id from vacancy_requirements where vacancy_id='$V1' and sort_order=1 and not is_deleted")
RQ_BIKE=$(sql "select id from vacancy_requirements where vacancy_id='$V1' and sort_order=2 and not is_deleted")
vapply() { (cd "$TMP" && curl -s -X POST "$API/worker/vacancies/$V1/apply" -H "Authorization: Bearer $1" -F "file_$RQ_FILE=@resume.pdf" -F "text_$RQ_AREA=$2" -F "text_$RQ_BIKE=$3"); }
did "   Ravi applies"  "$(vapply "$WT" Ollur yes)"
did "   Anita applies" "$(vapply "$W2" Kuttanellur no)"
A_RAVI=$(sql "select id from vacancy_applications where vacancy_id='$V1' and worker_profile_id='$WP1'")
did "   business shortlists Ravi" "$(P /business/vacancies/applications/$A_RAVI/status "$BT" '{"status":"Shortlisted","note":"Call on Monday"}')"
V2=$(P /business/vacancies "$BT" "{\"title\":\"Delivery driver\",\"jobTypeId\":\"$FULLTIME\",\"openings\":1,\"salaryMin\":14000,\"payPeriod\":\"PerMonth\",\"workingDaysPerWeek\":6,\"location\":\"Thrissur\",\"requirements\":[]}" | j id)
got "2 Job post not paid yet (shows 'Not posted yet')" "$V2"
rm -rf "$TMP"
fi

step "RESULT"
printf '  created ok: %s   failed: %s\n' "$OK" "$BAD"
logins
[ "$BAD" -eq 0 ]
