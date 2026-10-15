#!/usr/bin/env bash
# The three rules written into ConfirmPayoutCollectionCommandHandler, asked of the running app.
#
# Needs the API started with Razorpay__SimulateCollection=true, because every one of these is
# about what happens AFTER a payment is accepted — the refusal side is covered by
# e2e-pay-on-mobile.sh, which must run with simulation off.
#
#   1. a pay run belongs to one business, and nobody else can fund it
#   2. the same collection confirmed twice funds it once — a retried request, a duplicated
#      webhook and a double-tapped button all land here, and a second debit would be real money
#      taken twice
#   3. a closed run cannot be funded again
#
# Rule 2 is the one worth the script. Nothing anywhere asserted it, and it is the difference
# between a double tap being harmless and a worker being paid twice from the business's money.
API=${API:-http://localhost:5056/api/v1}
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-80; }

ok()  { PASS=$((PASS+1)); printf 'PASS  %-52s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-52s %s\n' "$1" "$2"; }
want_ok()   { if echo "$2" | grep -q '"success":true'; then ok "$1" "$3"; else bad "$1" "$(echo "$2" | msg)"; fi; }
want_fail() { if echo "$2" | grep -q '"success":true'; then bad "$1" "ACCEPTED — the rule should have refused it"; else ok "$1" "$(echo "$2" | msg)"; fi; }
eq()        { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }
step()      { printf '\n==== %s ====\n' "$1"; }

reg() { curl -s -X POST $API/auth/register -H 'Content-Type: application/json' \
  -d "{\"firstName\":\"$1\",\"lastName\":\"P\",\"email\":\"$2\",\"password\":\"E2e@12345\",\"phoneNumber\":\"9$(shuf -i 100000000-999999999 -n 1)\",\"role\":\"$3\"}"; }
P()  { local b="${3:-{\}}"; curl -s -X POST "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$b"; }
G()  { curl -s "$API$1" -H "Authorization: Bearer $2"; }

# A verified UPI destination, so disbursement has somewhere to send the money.
seedupi() { sql "insert into worker_payout_details (id,worker_profile_id,upi_vpa,account_holder_name,verification_status,verified_at,created_date,is_deleted,status) select gen_random_uuid(), w.id, '$2', 'E2E', 1, now(), now(), false, 1 from worker_profiles w join users u on u.id=w.user_id where u.email='$1'" >/dev/null; }

echo "=============================================================="
echo " PAY RUN RULES   $(date '+%Y-%m-%d %H:%M')"
echo "=============================================================="

step "0. A JOB WITH ONE WAGE OWED"
BT=$(reg Boss  "po_b$S@zuno.local" BusinessOwner | j accessToken)
B2=$(reg Rival "po_r$S@zuno.local" BusinessOwner | j accessToken)
WT=$(reg Ravi  "po_w$S@zuno.local" Worker        | j accessToken)
eq "Everyone signed up" "$([ -n "$BT" ] && [ -n "$B2" ] && [ -n "$WT" ] && echo yes)" "yes"
[ -n "$BT" ] && [ -n "$B2" ] && [ -n "$WT" ] || { echo "ABORTED"; exit 1; }

seedupi "po_w$S@zuno.local" "ravi$S@upi"

WHEN=$(date -u -d '+3 days 09:00' +%Y-%m-%dT%H:%M:%SZ)
POST=$(P /business/hiring-posts "$BT" "{\"title\":\"Payout rules $S\",\"eventDate\":\"$WHEN\",\"durationMinutes\":360,\"workersNeeded\":1,\"salaryAmount\":900,\"salaryUnit\":\"PerEvent\",\"location\":\"Varkala cliff\"}" | j id)
eq "Post created" "$([ -n "$POST" ] && echo yes)" "yes"
[ -n "$POST" ] || { echo "ABORTED: no post"; exit 1; }

want_ok "Worker invited"   "$(P "/business/hiring-posts/$POST/invite" "$BT" "{\"workerIdentifier\":\"po_w$S@zuno.local\"}")" ""
APP=$(sql "select id from hiring_post_applications where hiring_post_id='$POST' and is_deleted=false limit 1")
want_ok "Worker accepts"   "$(P "/worker/hiring-posts/applications/$APP/respond" "$WT" '{"accept":true}')" ""
# The day has to have arrived before work can start — the app refuses otherwise, which is the
# rule e2e-order-lifecycle.sh covers. Moved back here rather than waiting three days for it.
sql "update hiring_posts set event_date=now() - interval '1 hour' where id='$POST'" >/dev/null
want_ok "Work started"     "$(P "/business/hiring-posts/$POST/start" "$BT")" ""
want_ok "Work finished"    "$(P "/business/hiring-posts/$POST/complete" "$BT")" ""

step "1. A PAY RUN BELONGS TO ONE BUSINESS"
R=$(P "/business/hiring-posts/$POST/payouts" "$BT" '{"expectedTotal":900}')
want_ok "Pay run opened" "$R" ""
BATCH=$(echo "$R" | j payoutBatchId)
[ -n "$BATCH" ] || BATCH=$(sql "select id from payout_batches where hiring_post_id='$POST' limit 1")
eq "It has an id" "$([ -n "$BATCH" ] && echo yes)" "yes"
ORDER=$(sql "select coalesce(provider_order_id,'') from payout_batches where id='$BATCH'")

want_fail "Another business cannot fund it" \
  "$(P "/business/hiring-posts/payouts/$BATCH/confirm" "$B2" "{\"providerPaymentId\":\"pay_x$S\",\"signature\":\"sig\"}")"
eq "...and it is still unfunded" "$(sql "select funded_at is null from payout_batches where id='$BATCH'")" "t"
want_fail "A worker cannot fund it either" \
  "$(P "/business/hiring-posts/payouts/$BATCH/confirm" "$WT" "{\"providerPaymentId\":\"pay_x$S\",\"signature\":\"sig\"}")"

step "2. FUNDED ONCE, HOWEVER MANY TIMES IT IS CONFIRMED"
want_ok "The business confirms the collection" \
  "$(P "/business/hiring-posts/payouts/$BATCH/confirm" "$BT" "{\"providerPaymentId\":\"pay_first$S\",\"signature\":\"sim\"}")" ""
eq "Funded"                 "$(sql "select funded_at is not null from payout_batches where id='$BATCH'")" "t"
eq "The wage is paid"       "$(sql "select count(*) from payout_batch_items where payout_batch_id='$BATCH' and payment_status=3")" "1"
FUNDED_AT=$(sql "select funded_at from payout_batches where id='$BATCH'")
PAYMENT_ID=$(sql "select provider_payment_id from payout_batches where id='$BATCH'")
PAID_COUNT=$(sql "select count(*) from payout_batch_items where payout_batch_id='$BATCH' and paid_at is not null")

# The same call again, as a double tap or a retried request would make it.
AGAIN=$(P "/business/hiring-posts/payouts/$BATCH/confirm" "$BT" "{\"providerPaymentId\":\"pay_second$S\",\"signature\":\"sim\"}")
want_ok "Confirming again is accepted, not an error" "$AGAIN" "reads back the same run"
eq "...the funding moment did not move"   "$(sql "select funded_at from payout_batches where id='$BATCH'")" "$FUNDED_AT"
eq "...the payment it was funded by is unchanged" "$(sql "select provider_payment_id from payout_batches where id='$BATCH'")" "$PAYMENT_ID"
eq "...still exactly one paid line"       "$(sql "select count(*) from payout_batch_items where payout_batch_id='$BATCH' and paid_at is not null")" "$PAID_COUNT"
eq "...and the worker was told once, not twice (WagePaid)" \
   "$(sql "select count(*) from notifications n join users u on u.id=n.user_id where u.email='po_w$S@zuno.local' and n.kind=24")" "1"

step "3. A CLOSED RUN STAYS CLOSED"
eq "The run completed"  "$(sql "select batch_status from payout_batches where id='$BATCH'")" "3"
eq "Nothing outstanding on the job" \
   "$(sql "select count(*) from hiring_post_applications where hiring_post_id='$POST' and payment_status<>3")" "0"
want_fail "A second pay run for a settled job is refused" \
  "$(P "/business/hiring-posts/$POST/payouts" "$BT" '{"expectedTotal":900}')"

echo
echo "================ $PASS passed, $FAIL failed ================"
[ "$FAIL" -eq 0 ]
