#!/usr/bin/env bash
# Puts the four worker-availability scenarios onto the Test Owner account, so every case on the
# Workers tab can actually be seen in the app:
#
#   Ravi Kumar   two jobs on ONE date          → Booked, schedule shows one heading, two rows
#   Anita Menon  jobs on THREE different dates → Booked, schedule shows three headings
#   Suresh Nair  hired through a HIRING POST   → Booked (this is the case that used to read free)
#   Shajil S     nothing at all                → Active/free, schedule empty
#
# Everything is created through the real endpoints a customer and a business actually use —
# bookings placed by the customer, confirmed by the business, workers assigned through
# assign-worker, which runs the same clash check the app runs. Nothing is written straight into
# the tables, so what appears on screen is real data taking the real path.
#
# Dates are all relative to today, so this stays valid whenever it is run.
API=http://localhost:5056/api/v1
PSQL="${PSQL:-psql}"
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-100; }

ok()  { PASS=$((PASS+1)); printf 'PASS  %-54s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-54s %s\n' "$1" "$2"; }
want_ok() { if echo "$2" | grep -q '"success":true'; then ok "$1" "$3"; else bad "$1" "$(echo "$2" | msg)"; fi; }
eq()      { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }

post_() { local b="$3"; if [ -z "$b" ]; then b='{}'; fi
  curl -s -X POST "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$b"; }
get_()  { curl -s "$API$1" -H "Authorization: Bearer $2"; }
login() { curl -s -X POST $API/auth/login -H 'Content-Type: application/json' \
  -d "{\"email\":\"$1\",\"password\":\"$2\"}" | j accessToken; }

PW=${SEED_PASSWORD:-Zuno@123}

echo "================ SIGN IN ================"
BT=$(login owner@zuno.local "$PW")
CT=$(login customer@zuno.local "$PW")
if [ -z "$BT" ] || [ -z "$CT" ]; then
  echo "Could not sign in as owner@zuno.local / customer@zuno.local with the password tried."
  echo "Re-run with the right one:  SEED_PASSWORD='...' bash seed-worker-scenarios.sh"
  exit 1
fi
ok "Signed in as the business and the customer" "owner@zuno.local"

BIZ=$(sql "select b.id from business_owner_profiles b join users u on u.id=b.user_id where u.email='owner@zuno.local'")
wp() { sql "select w.id from worker_profiles w join users u on u.id=w.user_id where u.email='$1'"; }
RAVI=$(wp w1@zuno.local); ANITA=$(wp w2@zuno.local)
SURESH=$(wp w3@zuno.local); SHAJIL=$(wp shajil@zuno.local)
eq "Found the four roster workers" "$([ -n "$RAVI" ] && [ -n "$ANITA" ] && [ -n "$SURESH" ] && [ -n "$SHAJIL" ] && echo yes)" "yes"

# The business's own service, whatever it happens to be — nothing here assumes a name or an id.
SVC=$(get_ /business/services "$BT" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
eq "Using the business's own service" "$([ -n "$SVC" ] && echo yes)" "yes"

# Clear anything these four already hold, so the scenarios read cleanly rather than stacking on
# top of an earlier run. Only this business's own rows, and only future work.
sql "update booking_worker_assignments a set is_deleted=true
     from bookings b
     where b.id=a.booking_id
       and b.business_owner_profile_id='$BIZ'
       and b.scheduled_date > now()
       and a.worker_profile_id in ('$RAVI','$ANITA','$SURESH','$SHAJIL')" >/dev/null
ok "Cleared their existing future assignments" "starting from a known state"

day()  { date -u -d "+$1 days $2" +%Y-%m-%dT%H:%M:%SZ; }
book() {  # book <iso-date> -> booking id, confirmed
  local id
  id=$(post_ /customer/bookings "$CT" "{\"businessServiceId\":\"$SVC\",\"scheduledDate\":\"$1\",\"addressLine1\":\"14 Nila Nagar\",\"city\":\"Thrissur\",\"state\":\"Kerala\",\"postalCode\":\"680001\",\"country\":\"India\"}" | j id)
  post_ /business/bookings/$id/confirm "$BT" >/dev/null
  echo "$id"
}
assign() { post_ /business/bookings/$1/assign-worker "$BT" "{\"workerProfileId\":\"$2\"}"; }
slots()  { get_ /business/workers/$1/busy-dates "$BT" | grep -o '"startsAt"' | wc -l | tr -d ' '; }
badge()  { get_ /business/workers "$BT" | tr '{' '\n' | grep "\"workerProfileId\":\"$1\"" | grep -o '"availabilityStatus":"[^"]*"' | head -1 | cut -d'"' -f4; }

echo
echo "==== RAVI — TWO JOBS ON ONE DATE ===="
# Morning and late afternoon on the same day. Spaced well past the 30-minute travel rule, so
# the clash check allows both — which is exactly the situation worth showing.
R1=$(book "$(day 7 09:00)"); R2=$(book "$(day 7 16:00)")
want_ok "Morning job assigned"   "$(assign $R1 $RAVI)" "$(day 7 09:00)"
want_ok "Afternoon job assigned" "$(assign $R2 $RAVI)" "$(day 7 16:00)"
eq "Ravi reads as Booked"        "$(badge $RAVI)" "Booked"
eq "...with two entries on one date" "$(slots $RAVI)" "2"

echo
echo "==== ANITA — THREE DIFFERENT DATES ===="
A1=$(book "$(day 3 10:00)"); A2=$(book "$(day 9 11:00)"); A3=$(book "$(day 15 08:00)")
want_ok "First date assigned"  "$(assign $A1 $ANITA)" "$(day 3 10:00)"
want_ok "Second date assigned" "$(assign $A2 $ANITA)" "$(day 9 11:00)"
want_ok "Third date assigned"  "$(assign $A3 $ANITA)" "$(day 15 08:00)"
eq "Anita reads as Booked"     "$(badge $ANITA)" "Booked"
eq "...with three entries"     "$(slots $ANITA)" "3"

echo
echo "==== SURESH — HIRED THROUGH A HIRING POST ===="
# The case the badge used to miss entirely: held by a post, not a booking.
P=$(post_ /business/hiring-posts "$BT" "{\"title\":\"Evening crew\",\"eventDate\":\"$(day 11 18:00)\",\"durationMinutes\":180,\"workersNeeded\":1,\"salaryAmount\":800,\"salaryUnit\":\"PerEvent\",\"location\":\"14 Nila Nagar, Thrissur\"}" | j id)
want_ok "Hiring post created" "$(post_ /business/hiring-posts/$P/invite "$BT" '{"workerIdentifier":"w3@zuno.local"}')" "Suresh invited"
PA=$(sql "select a.id from hiring_post_applications a where a.hiring_post_id='$P' and a.worker_profile_id='$SURESH' and a.is_deleted=false limit 1")
WT=$(login w3@zuno.local "$PW")
if [ -z "$WT" ]; then
  bad "Suresh could not sign in to accept" "check the worker password"
else
  want_ok "Suresh accepts the offer" "$(post_ /worker/hiring-posts/applications/$PA/respond "$WT" '{"accept":true}')" ""
  eq "Suresh reads as Booked"        "$(badge $SURESH)" "Booked"
fi

echo
echo "==== SHAJIL — NOTHING ON ===="
eq "Shajil reads as free"      "$(badge $SHAJIL)" "Active"
eq "...and has an empty schedule" "$(slots $SHAJIL)" "0"

echo
echo "================ $PASS passed, $FAIL failed ================"
[ "$FAIL" -eq 0 ]
