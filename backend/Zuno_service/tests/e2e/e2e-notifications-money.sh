#!/usr/bin/env bash
# The two notifications about money, driven through the real endpoints.
#
# Split out from e2e-notifications.sh because these need Razorpay:SimulateCollection on, and the
# development secrets have it OFF — rightly, since it is the flag that lets a pay run be funded
# without money moving. So this runs against a THROWAWAY API instance on another port with the flag
# passed as an environment variable, and the real configuration is never touched.
#
#   WagePaid        the one notification in this app that is purely good news
#   PaymentDisputed the only one about money going missing, which must never be optional
#
# API base comes from the caller, so the throwaway instance's port can be passed in.
API=${API:-http://localhost:5057/api/v1}
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-110; }

ok()  { PASS=$((PASS+1)); printf 'PASS  %-58s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-58s %s\n' "$1" "$2"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }
has() { if echo "$2" | grep -qF "$3"; then ok "$1" "$3"; else bad "$1" "missing: $3"; fi; }
want_ok() { if echo "$2" | grep -q '"success":true'; then ok "$1" "$3"; else bad "$1" "$(echo "$2" | msg)"; fi; }

reg_once() {
  curl -s -X POST $API/auth/register -H 'Content-Type: application/json' \
    -d "{\"firstName\":\"$1\",\"lastName\":\"T\",\"email\":\"$2\",\"password\":\"E2e@12345\",\"phoneNumber\":\"9$((RANDOM%900000000+100000000))\",\"role\":\"$3\"}"
}
reg() {
  local body; body=$(reg_once "$1" "$2" "$3")
  if ! echo "$body" | grep -q '"accessToken"'; then sleep 63; body=$(reg_once "$1" "$2" "$3"); fi
  echo "$body"
}
post_() { local b="$3"; if [ -z "$b" ]; then b='{}'; fi
  curl -s -X POST "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$b"; }
# For the endpoints that answer 204 with no body, where looking for "success":true finds nothing
# and reports a working call as a failure.
code_() { local b="$3"; if [ -z "$b" ]; then b='{}'; fi
  curl -s -o /dev/null -w '%{http_code}' -X POST "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$b"; }
get_()  { curl -s "$API$1" -H "Authorization: Bearer $2"; }

# PaymentStatus, as the enum numbers it. Named here because a bare 3 in an assertion is a guess
# waiting to be wrong — which it was.
PAID=3
DISPUTED=5

IB=''
load() { IB=$(get_ "/notifications?take=100" "$1"); }
k() { echo "$IB" | tr '}' '\n' | grep -o "\"kind\":\"$1\"" | wc -l | tr -d ' '; }
t() { echo "$IB" | tr '}' '\n' | grep -F "\"kind\":\"$1\"" | head -1 | grep -o '"title":"[^"]*"' | cut -d'"' -f4; }
b() { echo "$IB" | tr '}' '\n' | grep -F "\"kind\":\"$1\"" | head -1 | grep -o '"body":"[^"]*"' | cut -d'"' -f4; }
g() {
  echo "$IB" | tr '}' '\n' | grep -F "\"kind\":\"$1\"" | head -1 \
    | grep -o '"target":"[^"]*","targetId":[^,]*' \
    | sed -e 's/"target":"//' -e 's/","targetId":/\//' -e 's/"//g'
}

echo "================ SETUP ================"
BT=$(reg Boss "mn_b$S@zuno.local" BusinessOwner | j accessToken)
WT=$(reg Ravi "mn_w$S@zuno.local" Worker | j accessToken)
eq "Business registered" "$([ -n "$BT" ] && echo yes)" "yes"
eq "Worker registered"   "$([ -n "$WT" ] && echo yes)" "yes"
if [ -z "$BT" ] || [ -z "$WT" ]; then echo; echo "ABORTED: an account could not be registered."; exit 1; fi

BIZ=$(sql "select b.id from business_owner_profiles b join users u on u.id=b.user_id where u.email='mn_b$S@zuno.local'")
sql "update business_owner_profiles set verification_status=1, verified_at=now() where id='$BIZ'" >/dev/null
WP=$(sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='mn_w$S@zuno.local'")

# Somewhere for the wages to land. Without a verified destination the disbursement is refused
# before it reaches the provider — correctly, and it would make this a test of that refusal.
sql "insert into worker_payout_details
       (id, worker_profile_id, upi_vpa, account_holder_name, verification_status, verified_at,
        is_deleted, status, created_date)
     values (gen_random_uuid(), '$WP', 'ravi@upi', 'Ravi T', 1, now(), false, 1, now())" >/dev/null
eq "Worker has a verified payout destination" "$(sql "select count(*) from worker_payout_details where worker_profile_id='$WP'")" "1"

echo
echo "==== A job worked and finished, so wages are owed ===="
SOON=$(date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ)
P=$(post_ /business/hiring-posts "$BT" "{\"title\":\"Varkala cliff catering\",\"eventDate\":\"$SOON\",\"durationMinutes\":120,\"workersNeeded\":1,\"salaryAmount\":900,\"salaryUnit\":\"PerEvent\",\"location\":\"Varkala\"}" | j id)
eq "Hiring post raised" "$([ -n "$P" ] && echo yes)" "yes"

want_ok "Worker invited" "$(post_ /business/hiring-posts/$P/invite "$BT" "{\"workerIdentifier\":\"mn_w$S@zuno.local\"}")" ""
PA=$(sql "select a.id from hiring_post_applications a where a.hiring_post_id='$P' and a.worker_profile_id='$WP' and a.is_deleted=false limit 1")
want_ok "Worker accepts" "$(post_ /worker/hiring-posts/applications/$PA/respond "$WT" '{"accept":true}')" ""

# The day arrives. Moved in the database rather than waited for, which is how the other lifecycle
# scripts do it — the rule being tested is about wages, not about the clock.
sql "update hiring_posts set event_date=now() - interval '3 hours' where id='$P'" >/dev/null
want_ok "Work started"  "$(post_ /business/hiring-posts/$P/start "$BT")" ""
want_ok "Work finished" "$(post_ /business/hiring-posts/$P/complete "$BT")" ""

echo
echo "==== 1. Wages sent: the worker is told, the business is not ===="
load "$WT"; BEFORE_W=$(k WagePaid)
load "$BT"; BEFORE_B=$(echo "$IB" | tr '}' '\n' | grep -c '"kind":"')

BATCH=$(post_ /business/hiring-posts/$P/payouts "$BT" '{}')
BID=$(echo "$BATCH" | j id)
eq "Pay run opened" "$([ -n "$BID" ] && echo yes)" "yes"

# No order id to sign against while collection is simulated, so the confirm step skips signature
# verification — the one path this throwaway instance exists to reach.
want_ok "Collection confirmed" "$(post_ /business/hiring-posts/payouts/$BID/confirm "$BT" '{"providerPaymentId":"sim_pay_e2e"}')" ""
eq "Every line paid" "$(sql "select count(*) from payout_batch_items where payout_batch_id='$BID' and payment_status=$PAID")" "1"

load "$WT"
eq  "Worker was told once, for this run"  "$(( $(k WagePaid) - BEFORE_W ))" "1"
has "Says how much, and what for"         "$(t WagePaid)" "₹900 paid for Varkala cliff catering"
has "...and invites them to speak up"     "$(b WagePaid)" "Tell us if it does not reach you."
eq  "Opens Payments, which needs no id"   "$(g WagePaid)" "Payments/null"

load "$BT"
eq "The business told itself nothing for its own payment" \
   "$(( $(echo "$IB" | tr '}' '\n' | grep -c '"kind":"') - BEFORE_B ))" "0"

echo
echo "==== 2. Wages disputed: the business is told, in the worker's own words ===="
eq "Worker reports it never arrived" \
   "$(code_ /worker/hiring-posts/applications/$PA/payment-response "$WT" '{"received":false,"disputeReason":"Nothing reached my UPI"}')" "204"
eq "Stored as disputed" "$(sql "select payment_status from hiring_post_applications where id='$PA'")" "$DISPUTED"

load "$BT"
eq  "Business was told once"      "$(k PaymentDisputed)" "1"
has "Names the worker and the money" "$(t PaymentDisputed)" "Ravi T reports they were not paid ₹900"
has "Carries their own reason"     "$(b PaymentDisputed)" "Nothing reached my UPI"
eq  "Opens the payouts for that job" "$(g PaymentDisputed)" "Payouts/$P"

load "$WT"
eq "The worker told itself nothing for its own report" "$(k PaymentDisputed)" "0"

echo
echo "==== 3. Confirming instead raises nothing ===="
# The happy answer needs no notification: the business already knows it paid, and a row saying so
# would be noise competing with the dispute above.
load "$BT"; BEFORE_B=$(echo "$IB" | tr '}' '\n' | grep -c '"kind":"')
eq "Worker confirms it arrived after all" \
   "$(code_ /worker/hiring-posts/applications/$PA/payment-response "$WT" '{"received":true}')" "204"
load "$BT"
eq "Nothing new reached the business" \
   "$(( $(echo "$IB" | tr '}' '\n' | grep -c '"kind":"') - BEFORE_B ))" "0"
eq "...and the dispute it was told about still stands on the record" "$(k PaymentDisputed)" "1"

echo
echo "================ TOTALS ================"
load "$BT"; printf 'Business  %2s notifications\n' "$(echo "$IB" | tr '}' '\n' | grep -c '"kind":"')"
load "$WT"; printf 'Worker    %2s notifications\n' "$(echo "$IB" | tr '}' '\n' | grep -c '"kind":"')"
echo
echo "PASS $PASS   FAIL $FAIL"
[ "$FAIL" -eq 0 ]
