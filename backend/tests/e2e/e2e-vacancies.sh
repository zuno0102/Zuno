#!/usr/bin/env bash
# Full-time vacancies, end to end: a business lists a job, pays the listing fee, workers apply with
# documents, the business reviews them, and the vacancy is stopped, reopened, renewed and deleted.
#
# Run against a scratch database with simulated collection on, so the fee can be confirmed without
# Razorpay Checkout:
#   Razorpay__SimulateCollection=true ConnectionStrings__ZunoDatabase=...zuno_scratch... dotnet run
#
# Sections
#   A  who can reach vacancies at all (customers never)
#   B  the options come from the tables (the Rs 49 plan)
#   C  writing a vacancy, and every rule that refuses one
#   D  unpaid means unseen
#   E  paying the listing fee
#   F  the worker feed
#   G  applying with documents, and files that are refused
#   H  the business reviews applicants; other businesses cannot
#   I  moving an applicant along tells the worker
#   J  stop, start again, expiry and renewal
#   K  withdrawing deletes the worker's documents
#   L  deleting the vacancy deletes everything at once
API=${API:-http://localhost:5056/api/v1}
PSQL="${PSQL:-psql}"
UPLOADS_ROOT=${UPLOADS_ROOT:-../../src/Zuno.Api}
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
jn()  { grep -o "\"$1\":[^,}\"]*" | head -1 | cut -d: -f2; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-80; }

ok()   { PASS=$((PASS+1)); printf '  PASS  %-60s %s\n' "$1" "$2"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %-60s %s\n' "$1" "$2"; }
eq()   { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' want '$3'"; fi; }
has()  { if echo "$2" | grep -qF -- "$3"; then ok "$1" "$3"; else bad "$1" "missing '$3'"; fi; }
hasnt(){ if echo "$2" | grep -qF -- "$3"; then bad "$1" "found '$3'"; else ok "$1" "absent"; fi; }
head_() { printf '\n== %s ==\n' "$1"; }

code() { local m="$1" p="$2" t="$3" b="${4:-{\}}"
  curl -s -o /dev/null -w '%{http_code}' -X "$m" "$API$p" ${t:+-H "Authorization: Bearer $t"} -H 'Content-Type: application/json' -d "$b"; }
body() { local m="$1" p="$2" t="$3" b="${4:-{\}}"
  curl -s -X "$m" "$API$p" -H "Authorization: Bearer $t" -H 'Content-Type: application/json' -d "$b"; }

reg() { curl -s -X POST $API/auth/register -H 'Content-Type: application/json' \
  -d "{\"firstName\":\"$1\",\"lastName\":\"T\",\"email\":\"$2\",\"password\":\"E2e@12345\",\"phoneNumber\":\"$3\",\"role\":\"$4\"}" | j accessToken; }
phone() { echo "9$(shuf -i 100000000-999999999 -n 1)"; }

echo "================================================================"
echo " ZUNO — FULL-TIME VACANCIES, END TO END"
echo " $(date '+%Y-%m-%d %H:%M')   against $API"
echo "================================================================"

BIZ=$(reg "VacBiz" "vbiz_$S@zuno.local" "$(phone)" BusinessOwner)
BIZ2=$(reg "VacBizTwo" "vbiz2_$S@zuno.local" "$(phone)" BusinessOwner)
W1=$(reg "VacWorker" "vw1_$S@zuno.local" "$(phone)" Worker)
W2=$(reg "VacWorkerTwo" "vw2_$S@zuno.local" "$(phone)" Worker)
CUS=$(reg "VacCustomer" "vcus_$S@zuno.local" "$(phone)" Customer)
[ -n "$BIZ" ] && [ -n "$BIZ2" ] && [ -n "$W1" ] && [ -n "$W2" ] && [ -n "$CUS" ] \
  && ok "Five accounts registered" "" || { bad "Registration" "an account did not register"; exit 1; }

head_ "A. WHO CAN REACH VACANCIES"
eq "No token: worker feed is 401"                 "$(code GET /worker/vacancies '')" "401"
eq "Customer: worker feed is 403"                 "$(code GET /worker/vacancies "$CUS")" "403"
eq "Customer: business vacancies is 403"          "$(code GET /business/vacancies "$CUS")" "403"
eq "Worker: business vacancies is 403"            "$(code GET /business/vacancies "$W1")" "403"
eq "Business: worker feed is 403"                 "$(code GET /worker/vacancies "$BIZ")" "403"

head_ "B. OPTIONS COME FROM THE TABLES"
OPT=$(body GET /business/vacancies/options "$BIZ")
has  "Fee plan is Rs 49"                          "$OPT" '"amount":49'
has  "Fee plan lists 30 days"                     "$OPT" '"listingDays":30'
has  "Job type Full-time"                         "$OPT" '"name":"Full-time"'
has  "Job type Contract has a fixed length"       "$OPT" '"name":"Contract","hasFixedLength":true'
has  "Upload types come from settings"           "$OPT" '"allowedFileExtensions":["pdf","jpg","jpeg","png"]'
FULLTIME=$(sql "select id from vacancy_job_types where name='Full-time'")
CONTRACT=$(sql "select id from vacancy_job_types where name='Contract'")

head_ "C. WRITING A VACANCY"
reqs='[{"kind":"File","prompt":"Resume","isRequired":true},{"kind":"File","prompt":"Aadhaar","isRequired":true},{"kind":"File","prompt":"Photo","isRequired":false},{"kind":"Text","prompt":"Do you know Tally?","isRequired":true},{"kind":"Number","prompt":"Years of experience","isRequired":false},{"kind":"YesNo","prompt":"Do you have a two-wheeler?","isRequired":false}]'
form() { echo "{\"title\":\"${1:-Office receptionist}\",\"jobTypeId\":\"${2:-$FULLTIME}\",\"openings\":2,\"salaryMin\":${3:-15000},\"salaryMax\":${4:-20000},\"payPeriod\":\"PerMonth\",\"workingDaysPerWeek\":6,\"shiftStart\":\"09:30:00\",\"shiftEnd\":\"18:00:00\"${5},\"location\":\"Near bus stand, Nagercoil\",\"latitude\":8.1833,\"longitude\":77.4119,\"requirements\":${6:-$reqs}}"; }
eq "Salary 0 is refused"                          "$(code POST /business/vacancies "$BIZ" "$(form '' '' 0 null)")" "400"
eq "Top of range below bottom is refused"         "$(code POST /business/vacancies "$BIZ" "$(form '' '' 20000 15000)")" "400"
eq "Empty title is refused"                       "$(code POST /business/vacancies "$BIZ" "$(form ' ')")" "400"
eq "Contract without months is refused"           "$(code POST /business/vacancies "$BIZ" "$(form 'Coolie' "$CONTRACT")")" "400"
eq "Question without wording is refused"          "$(code POST /business/vacancies "$BIZ" "$(form '' '' '' '' '' '[{"kind":"Question","isRequired":true}]')")" "400"
eq "Same field name twice is refused"             "$(code POST /business/vacancies "$BIZ" "$(form '' '' '' '' '' '[{"kind":"Text","prompt":"Area"},{"kind":"File","prompt":"area "}]')")" "400"
eq "Unknown field type is refused"                "$(code POST /business/vacancies "$BIZ" "$(form '' '' '' '' '' '[{"kind":"Signature","prompt":"Sign"}]')")" "400"
eq "Unknown job type is refused"                  "$(code POST /business/vacancies "$BIZ" "$(form '' 00000000-0000-0000-0000-000000000001)")" "400"
eq "Worker cannot create one"                     "$(code POST /business/vacancies "$W1" "$(form)")" "403"

CT=$(body POST /business/vacancies "$BIZ" "$(form 'Coolie work' "$CONTRACT" 600 null ',"contractMonths":1' '[]')")
eq "Contract with months is created"              "$(echo "$CT" | jn contractMonths)" "1"
CR=$(body POST /business/vacancies "$BIZ" "$(form)")
V=$(echo "$CR" | j id)
[ -n "$V" ] && ok "Receptionist vacancy created" "$V" || bad "Create" "$(echo "$CR" | msg)"
eq "It starts awaiting payment"                   "$(echo "$CR" | j status)" "AwaitingPayment"
eq "It needs payment"                             "$(echo "$CR" | jn needsPayment)" "true"
eq "It is not live"                               "$(echo "$CR" | jn isLive)" "false"
eq "Six custom fields saved"                        "$(sql "select count(*) from vacancy_requirements where vacancy_id='$V' and not is_deleted")" "6"
eq "Fields keep the business's own names"         "$(sql "select prompt from vacancy_requirements where vacancy_id='$V' and sort_order=1")" "Aadhaar"
eq "District derived from the pin"                "$(sql "select district_id is not null from vacancies where id='$V'")" "t"

head_ "D. UNPAID MEANS UNSEEN"
hasnt "Unpaid vacancy is not in the worker feed"  "$(body GET /worker/vacancies "$W1")" "$V"
eq "Worker cannot open an unpaid vacancy"         "$(code GET /worker/vacancies/$V "$W1")" "404"
eq "Stop hiring is refused before payment"        "$(code POST /business/vacancies/$V/stop-hiring "$BIZ")" "400"

head_ "E. PAYING THE LISTING FEE"
P1=$(body POST /business/vacancies/$V/payment "$BIZ")
eq "Order is for Rs 49"                           "$(echo "$P1" | jn amount)" "49.00"
eq "Order buys 30 days"                           "$(echo "$P1" | jn listingDays)" "30"
eq "Simulated: nothing to collect"                "$(echo "$P1" | jn nothingToCollect)" "true"
eq "Fee copied onto the vacancy"                  "$(sql "select fee_amount from vacancies where id='$V'")" "49.00"
eq "Other business cannot pay for it"             "$(code POST /business/vacancies/$V/payment "$BIZ2")" "404"
PC=$(body POST /business/vacancies/$V/payment/confirm "$BIZ" '{"providerPaymentId":"sim_pay_1"}')
eq "Paid: status Open"                            "$(echo "$PC" | j status)" "Open"
eq "Paid: live"                                   "$(echo "$PC" | jn isLive)" "true"
eq "Paid: expires in 30 days"                     "$(sql "select (expires_at - now()) between interval '29 days 23 hours' and interval '30 days 1 hour' from vacancies where id='$V'")" "t"
eq "Same payment confirmed again is harmless"     "$(code POST /business/vacancies/$V/payment/confirm "$BIZ" '{"providerPaymentId":"sim_pay_1"}')" "200"
eq "Paid only once"                               "$(sql "select paid_count from vacancies where id='$V'")" "1"
eq "Confirming with nothing pending is refused"   "$(code POST /business/vacancies/$V/payment/confirm "$BIZ" '{"providerPaymentId":"sim_pay_other"}')" "400"

head_ "F. THE WORKER FEED"
FEED=$(body GET "/worker/vacancies?latitude=8.18&longitude=77.41&radiusKm=20" "$W1")
has   "Live vacancy is in the feed nearby"        "$FEED" "$V"
has   "Distance is reported"                      "$FEED" '"distanceKm":'
hasnt "Far away it is not"                        "$(body GET "/worker/vacancies?latitude=13.08&longitude=80.27&radiusKm=20" "$W1")" "$V"
hasnt "Filtered to Contract it is not"            "$(body GET "/worker/vacancies?jobTypeId=$CONTRACT" "$W1")" "$V"
eq "Worker can open it"                           "$(code GET /worker/vacancies/$V "$W1")" "200"
eq "Page size above the cap is accepted"          "$(code GET "/worker/vacancies?take=1000" "$W1")" "200"
eq "Radius out of range is refused"               "$(code GET "/worker/vacancies?latitude=8&longitude=77&radiusKm=9999" "$W1")" "400"

head_ "G. APPLYING WITH DOCUMENTS"
RQ_RESUME=$(sql "select id from vacancy_requirements where vacancy_id='$V' and sort_order=0 and not is_deleted")
RQ_AADHAAR=$(sql "select id from vacancy_requirements where vacancy_id='$V' and sort_order=1 and not is_deleted")
RQ_Q=$(sql "select id from vacancy_requirements where vacancy_id='$V' and sort_order=3 and not is_deleted")
RQ_NUM=$(sql "select id from vacancy_requirements where vacancy_id='$V' and sort_order=4 and not is_deleted")
RQ_YN=$(sql "select id from vacancy_requirements where vacancy_id='$V' and sort_order=5 and not is_deleted")
printf '%%PDF-1.4\n%% resume\n' > "$TMP/resume.pdf"
printf '\x89PNG\r\n\x1a\n0000aadhaar' > "$TMP/aadhaar.png"
printf '#!/bin/sh\necho pwned\n' > "$TMP/evil.pdf"
apply() { curl -s -w '\n%{http_code}' -X POST "$API/worker/vacancies/$V/apply" -H "Authorization: Bearer $1" "${@:2}"; }

R=$(apply "$W1" -F "file_$RQ_RESUME=@$TMP/resume.pdf" -F "text_$RQ_Q=Yes")
eq "Missing required Aadhaar is refused"          "$(echo "$R" | tail -1)" "400"
R=$(apply "$W1" -F "file_$RQ_RESUME=@$TMP/evil.pdf" -F "file_$RQ_AADHAAR=@$TMP/aadhaar.png" -F "text_$RQ_Q=Yes")
eq "A script renamed .pdf is refused"             "$(echo "$R" | tail -1)" "400"
R=$(apply "$W1" -F "file_$RQ_RESUME=@$TMP/resume.pdf" -F "file_$RQ_AADHAAR=@$TMP/aadhaar.png")
eq "Missing required answer is refused"           "$(echo "$R" | tail -1)" "400"
R=$(apply "$W1" -F "file_$RQ_RESUME=@$TMP/resume.pdf" -F "file_$RQ_AADHAAR=@$TMP/aadhaar.png" -F "text_$RQ_Q=Yes" -F "text_$RQ_NUM=two")
eq "A Number field refuses words"                 "$(echo "$R" | tail -1)" "400"
R=$(apply "$W1" -F "file_$RQ_RESUME=@$TMP/resume.pdf" -F "file_$RQ_AADHAAR=@$TMP/aadhaar.png" -F "text_$RQ_Q=Yes" -F "text_$RQ_YN=maybe")
eq "A Yes/No field refuses anything else"        "$(echo "$R" | tail -1)" "400"
R=$(apply "$W1" -F "file_00000000-0000-0000-0000-000000000009=@$TMP/resume.pdf" -F "file_$RQ_RESUME=@$TMP/resume.pdf" -F "file_$RQ_AADHAAR=@$TMP/aadhaar.png" -F "text_$RQ_Q=Yes")
eq "A file for no requirement is refused"         "$(echo "$R" | tail -1)" "400"
eq "Nothing left on disk from refused attempts"   "$(find "$UPLOADS_ROOT/private-uploads/vacancies/$(echo "$V" | tr -d '-')" -type f 2>/dev/null | wc -l | tr -d ' ')" "0"
eq "Customer cannot apply"                        "$(apply "$CUS" -F "text_$RQ_Q=Yes" | tail -1)" "403"

R=$(apply "$W1" -F "file_$RQ_RESUME=@$TMP/resume.pdf" -F "file_$RQ_AADHAAR=@$TMP/aadhaar.png" -F "text_$RQ_Q=Yes, 2 years" -F "text_$RQ_NUM=2" -F "text_$RQ_YN=yes")
eq "Valid application is accepted"                "$(echo "$R" | tail -1)" "200"
eq "Worker sees Applied"                          "$(echo "$R" | head -1 | j myApplicationStatus)" "Applied"
eq "Applying twice is refused"                    "$(apply "$W1" -F "file_$RQ_RESUME=@$TMP/resume.pdf" -F "file_$RQ_AADHAAR=@$TMP/aadhaar.png" -F "text_$RQ_Q=Yes" | tail -1)" "400"
A1=$(sql "select id from vacancy_applications where vacancy_id='$V' and not is_deleted")
eq "Five answers saved (optional photo skipped)"  "$(sql "select count(*) from vacancy_application_answers where vacancy_application_id='$A1'")" "5"
eq "File named by the server, not the phone"      "$(sql "select file_name from vacancy_application_answers where vacancy_application_id='$A1' and sort_order=0")" "Resume.pdf"
eq "Two files in private storage"                 "$(find "$UPLOADS_ROOT/private-uploads/vacancies/$(echo "$V" | tr -d '-')" -type f | wc -l | tr -d ' ')" "2"
KEY=$(sql "select file_key from vacancy_application_answers where vacancy_application_id='$A1' and sort_order=0")
eq "Private file is not served under /uploads"    "$(curl -s --path-as-is -o /dev/null -w '%{http_code}' "${API%/api/v1}/uploads/../private-uploads/$KEY" | grep -c '^200$')" "0"
eq "Private file is not served at its own path"    "$(curl -s -o /dev/null -w '%{http_code}' "${API%/api/v1}/private-uploads/$KEY" | grep -c '^200$')" "0"
eq "Business told about the applicant"            "$(sql "select count(*) from notifications n join users u on u.id=n.user_id where u.email='vbiz_$S@zuno.local' and n.kind=49")" "1"

head_ "H. THE BUSINESS REVIEWS APPLICANTS"
APPS=$(body GET /business/vacancies/$V/applications "$BIZ")
has  "Applicant listed"                           "$APPS" "$A1"
has  "Phone shared with the business"             "$APPS" '"workerPhone":"9'
has  "Answer text shown"                          "$APPS" 'Yes, 2 years'
has  "Document flagged, with no URL"              "$APPS" '"hasFile":true'
hasnt "No storage key leaks"                      "$APPS" 'vacancies/'
DOC=$(sql "select id from vacancy_application_answers where vacancy_application_id='$A1' and sort_order=0")
eq "Owner downloads the resume"                   "$(curl -s -o "$TMP/dl.pdf" -w '%{http_code}' -H "Authorization: Bearer $BIZ" "$API/business/vacancies/documents/$DOC")" "200"
eq "Download is the same file"                    "$(cmp -s "$TMP/dl.pdf" "$TMP/resume.pdf" && echo same)" "same"
eq "Other business: applicants 404"               "$(code GET /business/vacancies/$V/applications "$BIZ2")" "404"
eq "Other business: document 404"                 "$(code GET /business/vacancies/documents/$DOC "$BIZ2")" "404"
eq "Worker: document 403"                         "$(code GET /business/vacancies/documents/$DOC "$W1")" "403"
eq "Other business: edit 404"                     "$(code PUT /business/vacancies/$V "$BIZ2" "$(form)")" "404"
eq "Other business: stop 404"                     "$(code POST /business/vacancies/$V/stop-hiring "$BIZ2")" "404"
eq "Other business: delete 404"                   "$(code DELETE /business/vacancies/$V "$BIZ2")" "404"
eq "Other business: move applicant 404"           "$(code POST /business/vacancies/applications/$A1/status "$BIZ2" '{"status":"Hired"}')" "404"
LIST=$(body GET /business/vacancies "$BIZ")
eq "Owner list counts the applicant"              "$(echo "$LIST" | grep -o '"applicantCount":[0-9]*' | sort | tail -1 | cut -d: -f2)" "1"
SUM=$(body GET /business/vacancies/summary "$BIZ")
eq "Home summary: one live post (unpaid one not counted)" "$(echo "$SUM" | jn activePosts)" "1"
eq "Home summary: one new applicant"              "$(echo "$SUM" | jn newCount)" "1"
eq "Other business sees none of it"               "$(body GET /business/vacancies/summary "$BIZ2" | jn newCount)" "0"
eq "Worker cannot read the summary"               "$(code GET /business/vacancies/summary "$W1")" "403"
eq "All jobs' New list has the applicant"        "$(body GET "/business/vacancies/applications?status=Applied" "$BIZ" | j id)" "$A1"
has  "Each applicant says which job"               "$(body GET "/business/vacancies/applications?status=Applied" "$BIZ")" '"vacancyTitle":"Office receptionist"'
hasnt "Another business's all-jobs list is empty"  "$(body GET /business/vacancies/applications "$BIZ2")" "$A1"

head_ "I. MOVING AN APPLICANT ALONG"
eq "New until opened: worker sees Applied"        "$(body GET /worker/vacancies/$V "$W1" | j myApplicationStatus)" "Applied"
eq "Owner's New list counts it"                  "$(body GET /business/vacancies "$BIZ" | grep -o '"newCount":[0-9]*' | sort | tail -1 | cut -d: -f2)" "1"
eq "Opening it marks it viewed"                   "$(body POST /business/vacancies/applications/$A1/viewed "$BIZ" | j status)" "Viewed"
eq "Worker sees Viewed"                           "$(body GET /worker/vacancies/$V "$W1" | j myApplicationStatus)" "Viewed"
eq "It moved to the Waiting list"                 "$(body GET "/business/vacancies/$V/applications?status=Viewed" "$BIZ" | j id)" "$A1"
eq "Opening again changes nothing"                "$(body POST /business/vacancies/applications/$A1/viewed "$BIZ" | j status)" "Viewed"
eq "Viewing is not news: no notification"         "$(sql "select count(*) from notifications n join users u on u.id=n.user_id where u.email='vw1_$S@zuno.local' and n.kind=50")" "0"
eq "Other business cannot mark it viewed"         "$(code POST /business/vacancies/applications/$A1/viewed "$BIZ2")" "404"
eq "Applied is not a decision"                    "$(code POST /business/vacancies/applications/$A1/status "$BIZ" '{"status":"Applied"}')" "400"
eq "Unknown status is refused"                    "$(code POST /business/vacancies/applications/$A1/status "$BIZ" '{"status":"Promoted"}')" "400"
ST=$(body POST /business/vacancies/applications/$A1/status "$BIZ" '{"status":"Shortlisted","note":"Call Monday"}')
eq "Shortlisted"                                  "$(echo "$ST" | j status)" "Shortlisted"
eq "Note kept"                                    "$(echo "$ST" | j businessNote)" "Call Monday"
eq "Worker sees Shortlisted"                      "$(body GET /worker/vacancies/$V "$W1" | j myApplicationStatus)" "Shortlisted"
eq "Worker told"                                  "$(sql "select count(*) from notifications n join users u on u.id=n.user_id where u.email='vw1_$S@zuno.local' and n.kind=50")" "1"
hasnt "Worker never sees the private note"        "$(body GET /worker/vacancies/$V "$W1")" "Call Monday"
eq "Same status again sends no second notice"     "$(body POST /business/vacancies/applications/$A1/status "$BIZ" '{"status":"Shortlisted"}' >/dev/null; sql "select count(*) from notifications n join users u on u.id=n.user_id where u.email='vw1_$S@zuno.local' and n.kind=50")" "1"
eq "My applications lists it"                     "$(body GET /worker/vacancies/applications "$W1" | j id)" "$V"

head_ "J. STOP, START AGAIN, EXPIRY, RENEWAL"
SP=$(body POST /business/vacancies/$V/stop-hiring "$BIZ")
eq "Stopped"                                      "$(echo "$SP" | j status)" "Stopped"
eq "Can start again"                              "$(echo "$SP" | jn canResume)" "true"
eq "Not deleted"                                  "$(sql "select is_deleted from vacancies where id='$V'")" "f"
hasnt "Gone from the feed"                        "$(body GET /worker/vacancies "$W2")" "$V"
eq "A new worker cannot open it"                  "$(code GET /worker/vacancies/$V "$W2")" "404"
eq "The applicant still can"                      "$(code GET /worker/vacancies/$V "$W1")" "200"
eq "Applying to a stopped vacancy is refused"     "$(apply "$W2" -F "text_$RQ_Q=Yes" | tail -1)" "400"
eq "Stopping twice is refused"                    "$(code POST /business/vacancies/$V/stop-hiring "$BIZ")" "400"
eq "Edit works while stopped"                     "$(code PUT /business/vacancies/$V "$BIZ" "$(form 'Front office receptionist')")" "200"
eq "Earlier answers keep their wording"           "$(sql "select count(*) from vacancy_application_answers where vacancy_application_id='$A1' and prompt='Do you know Tally?'")" "1"
STA=$(body POST /business/vacancies/$V/start-hiring "$BIZ")
eq "Started again for free"                       "$(echo "$STA" | j status)" "Open"
eq "No second payment taken"                      "$(sql "select paid_count from vacancies where id='$V'")" "1"
eq "Starting an open vacancy is refused"          "$(code POST /business/vacancies/$V/start-hiring "$BIZ")" "400"

body POST /business/vacancies/$V/stop-hiring "$BIZ" >/dev/null
sql "update vacancies set expires_at = now() - interval '1 minute' where id='$V'" >/dev/null
EXP=$(body GET /business/vacancies "$BIZ")
eq "Expired and stopped: cannot start again"      "$(code POST /business/vacancies/$V/start-hiring "$BIZ")" "400"
has "Expired: needs payment"                      "$(echo "$EXP" | tr '{' '\n' | grep "\"id\":\"$V\"")" '"needsPayment":true'
body POST /business/vacancies/$V/payment "$BIZ" >/dev/null
RN=$(body POST /business/vacancies/$V/payment/confirm "$BIZ" '{"providerPaymentId":"sim_pay_2"}')
eq "Renewed: still stopped (paying is not hiring)" "$(echo "$RN" | j status)" "Stopped"
eq "Renewed: paid twice"                          "$(sql "select paid_count from vacancies where id='$V'")" "2"
eq "Renewed: can start again"                     "$(code POST /business/vacancies/$V/start-hiring "$BIZ")" "200"

head_ "K. WITHDRAWING"
RQ_RESUME=$(sql "select id from vacancy_requirements where vacancy_id='$V' and sort_order=0 and not is_deleted")
RQ_AADHAAR=$(sql "select id from vacancy_requirements where vacancy_id='$V' and sort_order=1 and not is_deleted")
RQ_Q=$(sql "select id from vacancy_requirements where vacancy_id='$V' and sort_order=3 and not is_deleted")
eq "Second worker applies to the edited form"     "$(apply "$W2" -F "file_$RQ_RESUME=@$TMP/resume.pdf" -F "file_$RQ_AADHAAR=@$TMP/aadhaar.png" -F "text_$RQ_Q=No" | tail -1)" "200"
A2=$(sql "select a.id from vacancy_applications a join worker_profiles w on w.id=a.worker_profile_id join users u on u.id=w.user_id where u.email='vw2_$S@zuno.local' and not a.is_deleted")
A2N=$(echo "$A2" | tr -d '-')
eq "Their files are on disk"                      "$(find "$UPLOADS_ROOT/private-uploads/vacancies" -path "*$A2N*" -type f | wc -l | tr -d ' ')" "2"
eq "Another worker cannot withdraw it"            "$(code DELETE /worker/vacancies/applications/$A2 "$W1")" "404"
eq "They withdraw"                                "$(code DELETE /worker/vacancies/applications/$A2 "$W2")" "204"
eq "Their files are gone"                         "$(find "$UPLOADS_ROOT/private-uploads/vacancies" -path "*$A2N*" -type f | wc -l | tr -d ' ')" "0"
eq "Their answers are wiped"                      "$(sql "select count(*) from vacancy_application_answers where vacancy_application_id='$A2' and (answer_text is not null or file_key is not null)")" "0"
eq "They can apply again"                         "$(apply "$W2" -F "file_$RQ_RESUME=@$TMP/resume.pdf" -F "file_$RQ_AADHAAR=@$TMP/aadhaar.png" -F "text_$RQ_Q=No" | tail -1)" "200"
A2=$(sql "select a.id from vacancy_applications a join worker_profiles w on w.id=a.worker_profile_id join users u on u.id=w.user_id where u.email='vw2_$S@zuno.local' and not a.is_deleted")
A2N=$(echo "$A2" | tr -d '-')
eq "Rejecting them"                               "$(body POST /business/vacancies/applications/$A2/status "$BIZ" '{"status":"Rejected"}' | j status)" "Rejected"
eq "Rejected: their files are deleted"            "$(find "$UPLOADS_ROOT/private-uploads/vacancies" -path "*$A2N*" -type f | wc -l | tr -d ' ')" "0"
hasnt "Rejected: gone from the owner's lists"     "$(body GET /business/vacancies/$V/applications "$BIZ")" "$A2"
eq "Rejected: the worker still sees it"          "$(body GET /worker/vacancies/$V "$W2" | j myApplicationStatus)" "Rejected"
eq "Rejected: told about it"                      "$(sql "select count(*) from notifications n join users u on u.id=n.user_id where u.email='vw2_$S@zuno.local' and n.kind=50")" "1"
eq "Rejected is final"                            "$(code POST /business/vacancies/applications/$A2/status "$BIZ" '{"status":"Shortlisted"}')" "400"
body POST /business/vacancies/applications/$A1/status "$BIZ" '{"status":"Hired"}' >/dev/null
eq "A hired worker cannot withdraw"               "$(code DELETE /worker/vacancies/applications/$A1 "$W1")" "400"
body POST /business/vacancies/$V/stop-hiring "$BIZ" >/dev/null
eq "Stopped with someone hired"                   "$(body GET /business/vacancies "$BIZ" | tr '{' '
' | grep -c "\"id\":\"$V\".*\"status\":\"Stopped\"")" "1"
eq "Started again in one tap"                     "$(body POST /business/vacancies/$V/start-hiring "$BIZ" | j status)" "Open"
eq "The hire is still there after restarting"     "$(body GET "/business/vacancies/$V/applications?status=Hired" "$BIZ" | j id)" "$A1"
eq "The hired worker still sees Hired"            "$(body GET /worker/vacancies/$V "$W1" | j myApplicationStatus)" "Hired"

head_ "L. DELETING THE VACANCY"
eq "Owner deletes it"                             "$(code DELETE /business/vacancies/$V "$BIZ")" "204"
eq "Home summary after delete: nothing live"     "$(body GET /business/vacancies/summary "$BIZ" | jn activePosts)" "0"
hasnt "Gone from the owner's list"                "$(body GET /business/vacancies "$BIZ")" "$V"
eq "Gone for the applicant too"                   "$(code GET /worker/vacancies/$V "$W1")" "404"
eq "Every document deleted from disk"             "$(find "$UPLOADS_ROOT/private-uploads/vacancies/$(echo "$V" | tr -d '-')" -type f 2>/dev/null | wc -l | tr -d ' ')" "0"
eq "Every answer wiped"                           "$(sql "select count(*) from vacancy_application_answers x join vacancy_applications a on a.id=x.vacancy_application_id where a.vacancy_id='$V' and (x.answer_text is not null or x.file_key is not null)")" "0"
eq "The fee record is kept"                       "$(sql "select fee_amount from vacancies where id='$V'")" "49.00"
eq "Deleting again is 404"                        "$(code DELETE /business/vacancies/$V "$BIZ")" "404"

printf '\n================================================================\n'
printf ' %d passed, %d failed\n' "$PASS" "$FAIL"
printf '================================================================\n'
[ "$FAIL" -eq 0 ]
