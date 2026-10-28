#!/usr/bin/env bash
# Paying a crew from the phone, through Razorpay Checkout.
#
# The app now carries Razorpay's native SDK, so Android opens the real payment window rather
# than being told to go and find a browser. That makes the server's job the ordinary one: raise
# a genuine order, hand the app the order id and the publishable key, and refuse to release
# wages until a signature comes back that it can verify itself.
#
# What this pins — everything the phone depends on, and the line it must not be able to cross:
#   * a pay run comes back with a real Razorpay order and the publishable key to open it
#   * it is NOT flagged as nothing-to-collect, so the app opens Checkout rather than skipping it
#   * the key handed out is the publishable one; the secret never leaves the server
#   * confirming with no signature is refused
#   * confirming with a forged signature is refused
#   * after both refusals the crew is still unpaid and the completed count has not moved
#
# Checkout itself cannot be driven from a shell — a human types a UPI PIN on Razorpay's screen —
# so the successful leg is verified on the device. Everything up to and around it is here.
API=${API:-http://localhost:5056/api/v1}
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-100; }

ok()  { PASS=$((PASS+1)); printf 'PASS  %-54s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-54s %s\n' "$1" "$2"; }
want_ok()   { if echo "$2" | grep -q '"success":true'; then ok "$1" "$3"; else bad "$1" "$(echo "$2" | msg)"; fi; }
want_fail() { if echo "$2" | grep -q '"success":true'; then bad "$1" "it was accepted"; else ok "$1" "$(echo "$2" | msg)"; fi; }
eq()        { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }
starts()    { case "$2" in "$3"*) ok "$1" "$2";; *) bad "$1" "got '$2', expected it to start '$3'";; esac; }

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
seedupi() { sql "insert into worker_payout_details (id,worker_profile_id,upi_vpa,account_holder_name,verification_status,verified_at,created_date,is_deleted,status) select gen_random_uuid(), w.id, '$2', 'E2E', 1, now(), now(), false, 1 from worker_profiles w join users u on u.id=w.user_id where u.email='$1'" >/dev/null; }
counted() { sql "select completed_job_count from business_owner_profiles where id='$BIZ'"; }
field()   { echo "$1" | grep -o "\"$2\":[^,}]*" | head -1 | cut -d: -f2; }

echo "================ SETUP ================"
BT=$(reg Boss "pm_b$S@zuno.local" BusinessOwner | j accessToken)
W1=$(reg Ravi "pm_w1$S@zuno.local" Worker | j accessToken)
if [ -z "$BT" ] || [ -z "$W1" ]; then echo "registration failed (rate limit?)"; exit 1; fi
ok "Registered business and worker" "pm_b$S@zuno.local"

BIZ=$(sql "select b.id from business_owner_profiles b join users u on u.id=b.user_id where u.email='pm_b$S@zuno.local'")
sql "update business_owner_profiles set verification_status=1, verified_at=now() where id='$BIZ'" >/dev/null
seedupi "pm_w1$S@zuno.local" "ravi$S@okaxis"
WP=$(sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='pm_w1$S@zuno.local'")
eq "Starting count is zero" "$(counted)" "0"

# A standalone job the business runs for itself, so the whole thing lives on one post.
# Raised in the future because nobody can be invited to an event that has already happened, then
# the clock is wound forward so the work can start. Same trick the other suites use.
SOON=$(date -u -d '+2 days 10:00' +%Y-%m-%dT%H:%M:%SZ)
P=$(post_ /business/hiring-posts "$BT" "{\"title\":\"Depot shift\",\"eventDate\":\"$SOON\",\"durationMinutes\":120,\"workersNeeded\":1,\"salaryAmount\":900,\"salaryUnit\":\"PerEvent\",\"location\":\"Depot\"}" | j id)
want_ok "Worker invited" "$(post_ /business/hiring-posts/$P/invite "$BT" "{\"workerIdentifier\":\"pm_w1$S@zuno.local\"}")" ""
PA=$(sql "select a.id from hiring_post_applications a where a.hiring_post_id='$P' and a.worker_profile_id='$WP' and a.is_deleted=false limit 1")
want_ok "Worker accepts"      "$(post_ /worker/hiring-posts/applications/$PA/respond "$W1" '{"accept":true}')" ""
sql "update hiring_posts set event_date=now() - interval '1 hour' where id='$P'" >/dev/null
want_ok "Work started"        "$(post_ /business/hiring-posts/$P/start "$BT")" ""
want_ok "Work marked done"    "$(post_ /business/hiring-posts/$P/complete "$BT")" ""
eq "Not counted while unpaid" "$(counted)" "0"

echo
echo "==== 1. THE APP IS HANDED A REAL RAZORPAY ORDER ===="
R=$(post_ /business/hiring-posts/$P/payouts "$BT" '{"expectedTotal":900}')
want_ok "Pay run opened" "$R" ""
BATCH=$(echo "$R" | j id)
ORDER=$(echo "$R" | j providerOrderId)
KEY=$(echo "$R" | j razorpayKeyId)
starts "A genuine order to open"      "$ORDER" "order_"
starts "...with the publishable key"  "$KEY"   "rzp_test_"
# The flag is what the app keys off when deciding whether to open Checkout at all. False here
# means it opens — which is the whole point of the native SDK being in the build.
eq "Not flagged nothing-to-collect"   "$(field "$R" nothingToCollect)" "false"
eq "The order is stored server-side"  "$(sql "select provider_order_id='$ORDER' from payout_batches where id='$BATCH'")" "t"

# The one credential that must never be in a response. A leaked secret would let anyone forge the
# signature section 2 relies on, and every check under it would become decorative. Read from the
# server's own secret store rather than written here, so this cannot rot into checking for a
# value the API stopped using.
SECRET=$(dotnet user-secrets list --project "/c/Beaulin Shajil/Projects/MobileApps/Zuno/backend/src/Zuno.Api" 2>/dev/null \
  | grep '^Razorpay:KeySecret' | cut -d= -f2 | tr -d ' \r')
if [ -z "$SECRET" ]; then
  bad "The key secret stayed on the server" "could not read the secret to check against"
elif echo "$R" | grep -qF "$SECRET"; then
  bad "The key secret stayed on the server" "it was in the response"
else
  ok "The key secret stayed on the server" "only the publishable key went out"
fi

echo
echo "==== 2. WAGES ARE NOT RELEASED WITHOUT A VERIFIED PAYMENT ===="
# What the phone would send if the SDK returned nothing usable — the case the native code turns
# into a failure rather than passing along. Refused here too, so both ends hold the line.
want_fail "Empty signature refused" "$(post_ /business/hiring-posts/payouts/$BATCH/confirm "$BT" '{"providerPaymentId":"","signature":""}')"
# And an outright forgery: a plausible payment id with a signature that is merely the right shape.
FORGED=$(printf '%064d' 1 | tr '0' 'a')
want_fail "Forged signature refused" "$(post_ /business/hiring-posts/payouts/$BATCH/confirm "$BT" "{\"providerPaymentId\":\"pay_FORGED$S\",\"signature\":\"$FORGED\"}")"

echo
echo "==== 3. AND NOTHING MOVED ===="
eq "The worker is still unpaid"   "$(sql "select payment_status<>3 from hiring_post_applications where id='$PA'")" "t"
eq "The job is not settled"       "$(sql "select (settled_at is null) from hiring_posts where id='$P'")" "t"
eq "The completed count held"     "$(counted)" "0"
MINE=$(get_ /worker/hiring-posts "$W1" | tr '{' '\n' | grep -o '"myPaymentStatus":"[^"]*"' | head -1 | cut -d'"' -f4)
if [ "$MINE" = "Paid" ]; then bad "The worker is not told they were paid" "reads Paid"; else ok "The worker is not told they were paid" "$MINE"; fi

echo
echo "================ $PASS passed, $FAIL failed ================"
echo "The successful leg — typing a UPI PIN on Razorpay's own screen — is verified on the device."
[ "$FAIL" -eq 0 ]
