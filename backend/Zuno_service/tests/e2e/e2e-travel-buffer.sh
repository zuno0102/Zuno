#!/usr/bin/env bash
# The travel buffer between two jobs, tested at the exact boundary.
#
# The rule is "more than 30 minutes", not "at least 30": a worker finishing at 15:00 is free
# from 15:31, and 15:30 is refused. The old comparison allowed 15:30, and nothing in the suite
# ever tested the boundary itself — 15 minutes and 60 minutes were checked, so flipping the
# operator either way went unnoticed.
API=${API:-http://localhost:5056/api/v1}
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-110; }

ok()  { PASS=$((PASS+1)); printf 'PASS  %-54s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-54s %s\n' "$1" "$2"; }
want_ok() { if echo "$2" | grep -q '"success":true'; then ok "$1" "$3"; else bad "$1" "$(echo "$2" | msg)"; fi; }
want_no() { if echo "$2" | grep -q '"success":false'; then ok "$1" "$(echo "$2" | msg)"; else bad "$1" "ALLOWED but should have been refused"; fi; }
has()     { if echo "$2" | grep -qF "$3"; then ok "$1" "$3"; else bad "$1" "missing \"$3\" in: $(echo "$2" | msg)"; fi; }

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

mkpost() { post_ /business/hiring-posts "$BT" "{\"title\":\"$1\",\"eventDate\":\"$2\",\"durationMinutes\":$3,\"workersNeeded\":1,\"salaryAmount\":400,\"salaryUnit\":\"PerEvent\",\"location\":\"Nila nagar\"}" | j id; }
appid() { sql "select a.id from hiring_post_applications a join worker_profiles w on w.id=a.worker_profile_id join users u on u.id=w.user_id where a.hiring_post_id='$1' and u.email='$2' and a.is_deleted=false limit 1"; }

# Try to put the worker on a post at the given time. Failed invites leave no commitment behind
# (only an *accepted* application holds a worker), so these can run in any order.
try_at() { post_ /business/hiring-posts/"$(mkpost "$1" "$2" "$3")"/invite "$BT" "{\"workerIdentifier\":\"w1_$S@zuno.local\"}"; }

echo "================ SETUP ================"
BT=$(reg Boss "tb_b$S@zuno.local" BusinessOwner | j accessToken)
W1=$(reg Ravi "w1_$S@zuno.local" Worker | j accessToken)
if [ -z "$BT" ] || [ -z "$W1" ]; then echo "registration failed (rate limit?)"; exit 1; fi
ok "Registered business and one worker" "tb_b$S@zuno.local"

sql "update business_owner_profiles set verification_status=1, verified_at=now() where user_id=(select id from users where email='tb_b$S@zuno.local')" >/dev/null

# The baseline commitment: 1 Mar 2027, 12:00 to 15:00.
BASE=$(mkpost "Baseline 12:00-15:00" "2027-03-01T12:00:00Z" 180)
want_ok "Worker invited to the 12:00-15:00 job" "$(post_ /business/hiring-posts/$BASE/invite "$BT" "{\"workerIdentifier\":\"w1_$S@zuno.local\"}")" ""
BA=$(appid "$BASE" "w1_$S@zuno.local")
want_ok "Worker accepts it — now a real commitment" "$(post_ /worker/hiring-posts/applications/$BA/respond "$W1" '{"accept":true}')" "12:00-15:00 held"

echo
echo "==== 1. OVERLAP — REFUSED WITHOUT REFERENCE TO THE BUFFER ===="
want_no "13:00, inside the block"                  "$(try_at "Inside"      "2027-03-01T13:00:00Z" 60)"
want_no "14:59, one minute of overlap"             "$(try_at "One minute"  "2027-03-01T14:59:00Z" 60)"

echo
echo "==== 2. AFTER THE JOB — THE BOUNDARY ===="
want_no "15:00, straight after — zero gap"         "$(try_at "Zero gap"    "2027-03-01T15:00:00Z" 60)"
want_no "15:15, 15 minutes"                        "$(try_at "Fifteen"     "2027-03-01T15:15:00Z" 60)"
want_no "15:29, 29 minutes"                        "$(try_at "TwentyNine"  "2027-03-01T15:29:00Z" 60)"
# The case that decides < versus <=. Under the old rule this was allowed.
want_no "15:30, EXACTLY 30 — must be refused"      "$(try_at "Exactly30"   "2027-03-01T15:30:00Z" 60)"
want_ok "15:31, 31 minutes — the first slot free"  "$(try_at "ThirtyOne"   "2027-03-01T15:31:00Z" 60)" "allowed"

echo
echo "==== 3. BEFORE THE JOB — THE SAME BOUNDARY, MIRRORED ===="
# A 60-minute job starting at 10:30 ends at 11:30, exactly 30 before the 12:00 baseline.
want_no "Ends 11:30, exactly 30 before — refused"  "$(try_at "EndsExactly" "2027-03-01T10:30:00Z" 60)"
want_ok "Ends 11:29, 31 before — allowed"          "$(try_at "EndsEarlier" "2027-03-01T10:29:00Z" 60)" "allowed"

echo
echo "==== 4. THE MESSAGE TELLS THE TRUTH ABOUT THE RULE ===="
R=$(try_at "MessageCheck" "2027-03-01T15:30:00Z" 60)
has "Says 'more than', not 'at least'" "$R" "more than 30 minutes"
has "Quotes the actual gap"            "$R" "Only 30 minute(s)"

echo
echo "================ $PASS passed, $FAIL failed ================"
[ "$FAIL" -eq 0 ]
