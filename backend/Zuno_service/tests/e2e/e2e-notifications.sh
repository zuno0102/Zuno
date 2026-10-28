#!/usr/bin/env bash
# Notifications, driven entirely through the real endpoints.
#
# Every assertion is "somebody did a thing, and the right person was told, with a target that opens
# the right screen". Nothing is inserted into the notifications table directly — the point is to
# prove the chain from command handler to event to row.
#
# The two rules that matter most, and that are easiest to break:
#
#   * NOBODY IS TOLD ABOUT THEIR OWN ACTION. Checked after every step by counting what the actor
#     received, not just what the recipient did.
#   * ONE REAL-WORLD EVENT, ONE ROW. An assignment tells two people one thing each, never two each.
#
# Each person's inbox is fetched ONCE per section and parsed from a variable. Asserting three things
# used to mean three GETs, which ran this script into the API's own 100-per-minute limit and
# reported the feature as broken when it was the harness that was too hot.
API=${API:-http://localhost:5056/api/v1}
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-110; }

ok()  { PASS=$((PASS+1)); printf 'PASS  %-58s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-58s %s\n' "$1" "$2"; }
want_ok() { if echo "$2" | grep -q '"success":true'; then ok "$1" "$3"; else bad "$1" "$(echo "$2" | msg)"; fi; }
eq()      { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }
has()     { if echo "$2" | grep -qF "$3"; then ok "$1" "$3"; else bad "$1" "missing: $3"; fi; }

# The global limiter is 100 requests a minute per IP. Waited out rather than raised, because the
# limit protects the real thing and a test that needs it lifted is testing a different server.
cool() { printf '      ... waiting out the rate-limit window\n'; sleep 63; }

reg_once() {
  curl -s -X POST $API/auth/register -H 'Content-Type: application/json' \
    -d "{\"firstName\":\"$1\",\"lastName\":\"T\",\"email\":\"$2\",\"password\":\"E2e@12345\",\"phoneNumber\":\"9$((RANDOM%900000000+100000000))\",\"role\":\"$3\"}"
}

# Registration goes through the 5-per-minute auth limiter, which four accounts sit right on the
# edge of — and a run that follows another run inside the same minute goes over it. A silently
# empty token starves every later step and reports the feature as broken, so this waits the window
# out and tries once more rather than carrying on without the account.
reg() {
  local body
  body=$(reg_once "$1" "$2" "$3")
  if ! echo "$body" | grep -q '"accessToken"'; then
    printf '      ... register for %s was refused, waiting out the auth window\n' "$2" >&2
    sleep 63
    body=$(reg_once "$1" "$2" "$3")
  fi
  echo "$body"
}
post_() { local b="$3"; if [ -z "$b" ]; then b='{}'; fi
  curl -s -X POST "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$b"; }
code_() { curl -s -o /dev/null -w '%{http_code}' -X POST "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d '{}'; }
get_()  { curl -s "$API$1" -H "Authorization: Bearer $2"; }

# ---- one inbox, read once, asserted against many times --------------------------------------

IB=''
load()   { IB=$(get_ "/notifications?take=100" "$1"); }
unread() { get_ /notifications/unread-count "$1" | grep -o '"unreadCount":[0-9]*' | cut -d: -f2; }

# How many of one kind the loaded inbox holds.
k() { echo "$IB" | tr '}' '\n' | grep -o "\"kind\":\"$1\"" | wc -l | tr -d ' '; }

# The written words of the most recent notification of a kind.
t() {
  echo "$IB" | tr '}' '\n' | grep -F "\"kind\":\"$1\"" | head -1 \
    | grep -o '"title":"[^"]*"' | cut -d'"' -f4
}

# Where it leads, as "Target/id" — the pair that decides which screen opens.
g() {
  echo "$IB" | tr '}' '\n' | grep -F "\"kind\":\"$1\"" | head -1 \
    | grep -o '"target":"[^"]*","targetId":[^,]*' \
    | sed -e 's/"target":"//' -e 's/","targetId":/\//' -e 's/"//g'
}

n() { echo "$IB" | tr '}' '\n' | grep -c '"kind":"' | tr -d ' '; }

echo "================ SETUP ================"
# No logins anywhere in this script: registration already returns a token, and each login would
# spend one more of the five auth calls a minute allows.
BT=$(reg Boss "nt_b$S@zuno.local" BusinessOwner | j accessToken)
CT=$(reg Cust "nt_c$S@zuno.local" Customer | j accessToken)
W1=$(reg Ravi "nt_w1$S@zuno.local" Worker | j accessToken)
W2=$(reg Anita "nt_w2$S@zuno.local" Worker | j accessToken)

# One assertion each, so a missing token is named rather than hidden behind a single "yes".
# Everything after this depends on all four, so the run stops here instead of reporting fifty
# downstream failures that all mean "one account never registered".
eq "Business registered" "$([ -n "$BT" ] && echo yes)" "yes"
eq "Customer registered" "$([ -n "$CT" ] && echo yes)" "yes"
eq "Worker 1 registered" "$([ -n "$W1" ] && echo yes)" "yes"
eq "Worker 2 registered" "$([ -n "$W2" ] && echo yes)" "yes"
if [ -z "$BT" ] || [ -z "$CT" ] || [ -z "$W1" ] || [ -z "$W2" ]; then
  echo
  echo "ABORTED: an account could not be registered, so nothing below would mean anything."
  exit 1
fi

BIZ=$(sql "select b.id from business_owner_profiles b join users u on u.id=b.user_id where u.email='nt_b$S@zuno.local'")
sql "update business_owner_profiles set verification_status=1, verified_at=now() where id='$BIZ'" >/dev/null
DIST=$(sql "select id from districts limit 1")
WP1=$(sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='nt_w1$S@zuno.local'")
WP2=$(sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='nt_w2$S@zuno.local'")

SVC=$(post_ /business/services "$BT" "{\"serviceCategoryId\":\"a1111111-0000-0000-0000-000000000003\",\"name\":\"Catering\",\"priceType\":\"Fixed\",\"price\":5000,\"requiredWorkerCount\":1,\"estimatedDurationMinutes\":120,\"districtIds\":[\"$DIST\"]}" | j id)
eq "Service created" "$([ -n "$SVC" ] && echo yes)" "yes"

echo
echo "==== A fresh account has an empty inbox ===="
load "$BT"
eq "Nothing told to the business yet" "$(n)" "0"
eq "Badge reads zero"                 "$(unread "$BT")" "0"

echo
echo "==== 1. A team invitation reaches the worker ===="
want_ok "Business invites the worker to its crew" "$(post_ /business/workers/invite "$BT" "{\"workerIdentifier\":\"nt_w1$S@zuno.local\"}")" ""
load "$W1"
eq  "Worker was told once"   "$(k TeamInvitation)" "1"
has "In the business's name" "$(t TeamInvitation)" "Boss T wants you on their team"
eq  "Opens the Invitations tab, no id needed" "$(g TeamInvitation)" "Invitations/null"
load "$BT"
eq  "The business told itself nothing" "$(n)" "0"

INV=$(get_ /worker/invitations "$W1" | j id)
post_ /worker/invitations/$INV/respond "$W1" '{"accept":true}' >/dev/null

echo
echo "==== 2. A new order reaches the business ===="
FUTURE=$(date -u -d '+3 days 10:00' +%Y-%m-%dT%H:%M:%SZ)
BK=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$FUTURE\",\"addressLine1\":\"14 Nila Nagar\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"latitude\":10.5276,\"longitude\":76.2144,\"country\":\"India\"}" | j id)
eq "Order placed" "$([ -n "$BK" ] && echo yes)" "yes"
load "$BT"
eq  "Business was told once" "$(k BookingRequested)" "1"
has "Says what and when"     "$(t BookingRequested)" "New booking request"
eq  "Opens that order"       "$(g BookingRequested)" "Booking/$BK"
load "$CT"
eq  "The customer told itself nothing" "$(n)" "0"

echo
echo "==== 3. An offer reaches whichever side is waiting ===="
want_ok "Business proposes terms" "$(post_ /business/bookings/$BK/terms "$BT" '{"workerCount":2,"price":12000}')" ""
load "$CT"
eq  "Customer was told once"         "$(k BookingTermsProposed)" "1"
has "Carries the money and the crew" "$(t BookingTermsProposed)" "proposed ₹12,000 for 2 crew"
eq  "Opens that order"               "$(g BookingTermsProposed)" "Booking/$BK"

# ...and the other direction, which the catalogue did not promise but an open order needs.
want_ok "Customer counters" "$(post_ /customer/bookings/$BK/terms "$CT" '{"workerCount":2,"price":10000}')" ""
load "$BT"
eq  "Business was told about the counter" "$(k BookingTermsProposed)" "1"
has "Named as the customer"               "$(t BookingTermsProposed)" "Cust T proposed ₹10,000"

PROP=$(sql "select id from booking_agreement_proposals where booking_id='$BK' and proposal_status=1 limit 1")
post_ /business/bookings/$BK/terms/$PROP/accept "$BT" >/dev/null

echo
echo "==== 4. A confirmation reaches the customer ===="
BK2=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$FUTURE\",\"addressLine1\":\"14 Nila Nagar\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"latitude\":10.5276,\"longitude\":76.2144,\"country\":\"India\"}" | j id)
want_ok "Business confirms it outright" "$(post_ /business/bookings/$BK2/confirm "$BT")" ""
load "$CT"
eq  "Customer was told once" "$(k BookingConfirmed)" "1"
has "Names the business"     "$(t BookingConfirmed)" "Boss T confirmed your booking"
eq  "Opens that order"       "$(g BookingConfirmed)" "Booking/$BK2"
BEFORE_C=$(n)
load "$W1"; BEFORE_W=$(n)
load "$BT"; BEFORE_B=$(n)

echo
echo "==== 5. One assignment, two people told, one row each ===="
want_ok "Worker put on the order" "$(post_ /business/bookings/$BK2/assign-worker "$BT" "{\"workerProfileId\":\"$WP1\"}")" ""
load "$CT"
eq  "Customer told exactly once"      "$(( $(n) - BEFORE_C ))" "1"
has "The customer hears about a crew" "$(t BookingCrewAssigned)" "Your crew is set"
load "$W1"
eq  "Worker told exactly once"      "$(( $(n) - BEFORE_W ))" "1"
has "The worker hears about a job"  "$(t JobAssignment)" "You're on a job"
eq  "...and it opens that booking"  "$(g JobAssignment)" "Booking/$BK2"
load "$BT"
eq  "Business told nothing" "$(( $(n) - BEFORE_B ))" "0"

echo
echo "==== 6. The worker's answer reaches the business ===="
want_ok "Worker accepts" "$(post_ /worker/jobs/$BK2/respond "$W1" '{"accept":true}')" ""
load "$BT"
eq  "Business was told once"  "$(k AssignmentAnswered)" "1"
has "Says who, and which way" "$(t AssignmentAnswered)" "Ravi T accepted the job"
load "$W1"
eq  "Worker got nothing for its own answer" "$(k AssignmentAnswered)" "0"

cool

echo
echo "==== 7. Work starting, finishing, and the ask to rate ===="
sql "update bookings set scheduled_date=now() - interval '1 hour' where id='$BK2'" >/dev/null
want_ok "Business starts the work" "$(post_ /business/bookings/$BK2/start "$BT")" ""
load "$CT"
eq  "Customer was told once" "$(k BookingWorkStarted)" "1"
has "Names the business"     "$(t BookingWorkStarted)" "Boss T has started your job"

want_ok "Worker marks their part done" "$(post_ /worker/jobs/$BK2/complete "$W1")" ""
load "$BT"
eq  "Business was told once"  "$(k WorkerFinishedWork)" "1"
has "Names the worker"        "$(t WorkerFinishedWork)" "Ravi T finished their part"
load "$CT"
eq  "Customer was asked to rate"        "$(k BookingCompleted)" "1"
has "...as an ask, not an announcement" "$(t BookingCompleted)" "Work finished. Rate Boss T?"
eq  "...and it opens the rating"        "$(g BookingCompleted)" "BookingRating/$BK2"

echo
echo "==== 8. The rating reaches the business ===="
want_ok "Customer rates it" "$(post_ /customer/bookings/$BK2/rate "$CT" '{"score":5,"comment":"On time"}')" ""
load "$BT"
eq  "Business was told once"       "$(k RatingReceived)" "1"
has "Says how many stars"          "$(t RatingReceived)" "You were rated 5 stars"
eq  "Opens its own profile, no id" "$(g RatingReceived)" "Profile/null"

echo
echo "==== 9. A chat message reaches the other side only ===="
want_ok "Customer writes on the open order" "$(post_ /bookings/$BK/messages "$CT" '{"body":"Can you come at 5?"}')" ""
load "$BT"
eq  "Business was told once" "$(k ChatMessage)" "1"
has "Titled with the sender" "$(t ChatMessage)" "Cust T"
eq  "Opens that thread"      "$(g ChatMessage)" "BookingChat/$BK"
load "$CT"
eq  "Customer told itself nothing" "$(k ChatMessage)" "0"

echo
echo "==== 10. Hiring: an invitation, carrying the wage ===="
SOON=$(date -u -d '+2 days 10:00' +%Y-%m-%dT%H:%M:%SZ)
P=$(post_ /business/hiring-posts "$BT" "{\"title\":\"Varkala cliff catering\",\"eventDate\":\"$SOON\",\"durationMinutes\":120,\"workersNeeded\":2,\"salaryAmount\":900,\"salaryUnit\":\"PerEvent\",\"location\":\"Varkala\"}" | j id)
want_ok "Worker invited onto the post" "$(post_ /business/hiring-posts/$P/invite "$BT" "{\"workerIdentifier\":\"nt_w2$S@zuno.local\"}")" ""
load "$W2"
eq  "Worker was told once"   "$(k JobInvitation)" "1"
has "Names the job"          "$(t JobInvitation)" "Boss T invited you to Varkala cliff catering"
eq  "Opens that post"        "$(g JobInvitation)" "HiringPost/$P"
# The wage is the one fact that decides whether this gets opened at all.
has "Carries the wage and its unit" "$IB" "₹900 per event"

echo
echo "==== 11. Hiring: the worker's answer, and a raise ===="
PA=$(sql "select a.id from hiring_post_applications a where a.hiring_post_id='$P' and a.worker_profile_id='$WP2' and a.is_deleted=false limit 1")
want_ok "Worker accepts the offer" "$(post_ /worker/hiring-posts/applications/$PA/respond "$W2" '{"accept":true}')" ""
load "$BT"
eq  "Business was told once"  "$(k OfferAnswered)" "1"
has "Says who, and which way" "$(t OfferAnswered)" "Anita T accepted Varkala cliff catering"

want_ok "Business raises the agreed wage" "$(post_ /business/hiring-posts/applications/$PA/salary "$BT" '{"newAmount":1100,"reason":"Stayed late"}')" ""
load "$W2"
eq  "Worker was told once"   "$(k WageRaised)" "1"
has "Carries the new figure"  "$(t WageRaised)" "went up to ₹1,100 per event"
eq  "Opens that post"         "$(g WageRaised)" "HiringPost/$P"

cool

echo
echo "==== 12. Hiring: an application reaches the business ===="
want_ok "The other worker applies" "$(post_ /worker/hiring-posts/$P/apply "$W1" '{}')" ""
load "$BT"
eq  "Business was told once"       "$(k NewApplicants)" "1"
has "Names the applicant"          "$(t NewApplicants)" "Ravi T applied to Varkala cliff catering"
eq  "Opens that post's applicants" "$(g NewApplicants)" "HiringPostApplicants/$P"

APA=$(sql "select a.id from hiring_post_applications a where a.hiring_post_id='$P' and a.worker_profile_id='$WP1' and a.is_deleted=false limit 1")
want_ok "Business turns them down" "$(post_ /business/hiring-posts/applications/$APA/reject "$BT")" ""
load "$W1"
eq  "Worker was told once" "$(k ApplicationRejected)" "1"
eq  "Sent to Find work, not the post they lost" "$(g ApplicationRejected)" "FindWork/null"

echo
echo "==== 13. A cancellation reaches the other side and the crew ===="
LATER=$(date -u -d '+9 days 10:00' +%Y-%m-%dT%H:%M:%SZ)
BK3=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$LATER\",\"addressLine1\":\"14 Nila Nagar\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"latitude\":10.5276,\"longitude\":76.2144,\"country\":\"India\"}" | j id)
post_ /business/bookings/$BK3/confirm "$BT" >/dev/null
post_ /business/bookings/$BK3/assign-worker "$BT" "{\"workerProfileId\":\"$WP1\"}" >/dev/null

load "$CT"; BEFORE_C=$(n)
want_ok "Customer calls it off" "$(post_ /customer/bookings/$BK3/cancel "$CT" '{"reason":"Changed plans"}')" ""
load "$BT"
eq  "Business was told once" "$(k BookingCancelledByCustomer)" "1"
has "Names the customer"     "$(t BookingCancelledByCustomer)" "Cust T cancelled their booking"
load "$W1"
eq  "The worker on it was told" "$(k JobCancelled)" "1"
eq  "...and sent to My jobs"    "$(g JobCancelled)" "MyJobs/null"
load "$CT"
eq  "The customer told itself nothing" "$(( $(n) - BEFORE_C ))" "0"

echo
echo "==== 13b. The other cancel direction: the business declining ===="
# A business may only turn an order down while it is still pending — after confirming, cancelling
# is the customer's to do. So this one is left unconfirmed on purpose.
BK4=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$LATER\",\"addressLine1\":\"14 Nila Nagar\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"latitude\":10.5276,\"longitude\":76.2144,\"country\":\"India\"}" | j id)
want_ok "Business declines the order" "$(post_ /business/bookings/$BK4/cancel "$BT" '{"reason":"Fully booked"}')" ""
load "$CT"
eq  "Customer was told once" "$(k BookingCancelledByBusiness)" "1"
has "Names the business"     "$(t BookingCancelledByBusiness)" "Boss T cancelled your booking"
eq  "Opens that order"       "$(g BookingCancelledByBusiness)" "Booking/$BK4"

cool

echo
echo "==== 13c. An applicant picked out, rather than turned down ===="
# A different week from the first post on purpose. Anita already accepted that one, and the clash
# check would rightly refuse to put her on two jobs at the same hour — which would make this a test
# of the clash rule rather than of the notification.
OTHER_WEEK=$(date -u -d '+16 days 10:00' +%Y-%m-%dT%H:%M:%SZ)
P2=$(post_ /business/hiring-posts "$BT" "{\"title\":\"Kovalam beach servers\",\"eventDate\":\"$OTHER_WEEK\",\"durationMinutes\":120,\"workersNeeded\":1,\"salaryAmount\":800,\"salaryUnit\":\"PerEvent\",\"location\":\"Kovalam\"}" | j id)
want_ok "Worker applies"  "$(post_ /worker/hiring-posts/$P2/apply "$W2" '{}')" ""
P2A=$(sql "select a.id from hiring_post_applications a where a.hiring_post_id='$P2' and a.worker_profile_id='$WP2' and a.is_deleted=false limit 1")
want_ok "Business hires them" "$(post_ /business/hiring-posts/applications/$P2A/confirm "$BT")" ""
load "$W2"
eq  "Worker was told once" "$(k JobOfferConfirmed)" "1"
has "Says they were hired" "$(t JobOfferConfirmed)" "Boss T hired you for Kovalam beach servers"
eq  "Opens My jobs, where the job now is" "$(g JobOfferConfirmed)" "MyJobs/null"

cool

echo
echo "==== 14. The badge, and marking things read ===="
load "$BT"
HELD=$(n)
UNREAD_B=$(unread "$BT")
eq "Everything the business holds is unread" "$UNREAD_B" "$HELD"

NID=$(echo "$IB" | j id)
eq "One marked read"                  "$(code_ /notifications/$NID/read "$BT")" "204"
eq "Badge dropped by one"             "$(unread "$BT")" "$(( UNREAD_B - 1 ))"
eq "Marking it read again is no error" "$(code_ /notifications/$NID/read "$BT")" "204"
eq "...and the badge did not move"     "$(unread "$BT")" "$(( UNREAD_B - 1 ))"

eq "Somebody else's notification is not found" "$(code_ /notifications/$NID/read "$W1")" "404"

eq "Read-all clears the badge"       "$(code_ /notifications/read-all "$BT")" "204"
eq "Badge now zero"                  "$(unread "$BT")" "0"
load "$BT"
eq "...and the rows are still there"  "$(n)" "$HELD"

echo
echo "==== 15. Nobody reads anybody else's inbox ===="
eq "Unauthenticated is refused" "$(curl -s -o /dev/null -w '%{http_code}' "$API/notifications")" "401"
# Each inbox holds only its own rows: the worker never sees the business's, by construction above.
load "$W1"
eq "The worker holds no business notifications" "$(k BookingRequested)" "0"
load "$BT"
eq "The business holds no worker notifications" "$(k JobInvitation)" "0"

echo
echo "================ TOTALS ================"
for who in "Business:$BT" "Customer:$CT" "Worker 1:$W1" "Worker 2:$W2"; do
  load "${who#*:}"
  printf '%-10s %2s notifications\n' "${who%%:*}" "$(n)"
done
echo
echo "PASS $PASS   FAIL $FAIL"
[ "$FAIL" -eq 0 ]
