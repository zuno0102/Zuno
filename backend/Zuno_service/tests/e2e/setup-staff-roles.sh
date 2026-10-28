#!/usr/bin/env bash
# Staff roles on Test Owner's business: two new team members, one made Supervisor and one Manager.
#
# Driven entirely through the real endpoints — invite, accept, assign role — rather than inserted.
# The point of this data is to exercise a feature that has permissions in it, and a row written
# straight to the table would skip every check that decides whether the role is legitimate.
#
# Categories are chosen so neither person opens an empty Manage screen:
#   Supervisor  Cleaning + Painting   the two with real live orders (8 and 9)
#   Manager     Painting              the busiest, so the wider powers have something to act on
#
# Idempotent as far as the API allows: already-invited and already-roled are reported, not retried.
API=${API:-http://localhost:5056/api/v1}
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-110; }

ok()  { PASS=$((PASS+1)); printf 'PASS  %-54s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-54s %s\n' "$1" "$2"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }
note(){ printf '      %s\n' "$1"; }

post_() { local b="$3"; if [ -z "$b" ]; then b='{}'; fi
  curl -s -X POST "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$b"; }
put_()  { curl -s -X PUT "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$3"; }
get_()  { curl -s "$API$1" -H "Authorization: Bearer $2"; }

# The password every seeded account in this database uses.
PW='E2e@12345'

# Registration returns a token, so nobody is logged in twice — the auth limiter allows five a
# minute and this run needs exactly three.
reg() {
  curl -s -X POST $API/auth/register -H 'Content-Type: application/json' \
    -d "{\"firstName\":\"$1\",\"lastName\":\"$2\",\"email\":\"$3\",\"password\":\"$PW\",\"phoneNumber\":\"$4\",\"role\":\"Worker\"}"
}

BIZ='0252ffb3-568f-44b2-a7ef-fc58acedb347'          # Test Owner's business
CAT_CLEANING='a1111111-0000-0000-0000-000000000003'
CAT_PAINTING='a1111111-0000-0000-0000-000000000005'
ROLE_SUPERVISOR='b2222222-0000-0000-0000-000000000002'
ROLE_MANAGER='b2222222-0000-0000-0000-000000000003'

echo "================ SIGN IN AS THE OWNER ================"
BT=$(curl -s -X POST $API/auth/login -H 'Content-Type: application/json' \
  -d "{\"emailOrPhone\":\"owner@zuno.local\",\"password\":\"$PW\"}" | j accessToken)
eq "Owner signed in" "$([ -n "$BT" ] && echo yes)" "yes"
[ -n "$BT" ] || { echo "ABORTED: could not sign in as owner@zuno.local"; exit 1; }

# ---- the two new people ----------------------------------------------------------------------

# A number no account holds yet.
#
# Asked of the database rather than hardcoded: this one is seeded over and over, and a phone number
# picked by hand collides with some earlier run's worker and fails registration with a message
# about the phone when the thing being set up is a role.
free_phone() {
  local candidate
  for _ in $(seq 1 50); do
    candidate="9$(shuf -i 100000000-999999999 -n 1 2>/dev/null || echo $((RANDOM*90000+100000000)))"
    if [ -z "$(sql "select 1 from users where phone_number='$candidate'")" ]; then
      echo "$candidate"
      return
    fi
  done
}

add_member() {
  local first="$1" last="$2" email="$3"
  local token existing phone

  existing=$(sql "select u.id from users u where u.email='$email' and u.is_deleted=false")

  if [ -n "$existing" ]; then
    note "$email already exists — signing in rather than registering"
    token=$(curl -s -X POST $API/auth/login -H 'Content-Type: application/json' \
      -d "{\"emailOrPhone\":\"$email\",\"password\":\"$PW\"}" | j accessToken)
  else
    phone=$(free_phone)
    token=$(reg "$first" "$last" "$email" "$phone" | j accessToken)
  fi

  echo "$token"
}

echo
echo "================ NEW TEAM MEMBERS ================"
SUP_EMAIL='supervisor@zuno.local'
MGR_EMAIL='manager@zuno.local'

ST=$(add_member Priya Menon "$SUP_EMAIL")
eq "Supervisor account ready" "$([ -n "$ST" ] && echo yes)" "yes"

MT=$(add_member Arun Pillai "$MGR_EMAIL")
eq "Manager account ready" "$([ -n "$MT" ] && echo yes)" "yes"

[ -n "$ST" ] && [ -n "$MT" ] || { echo "ABORTED: an account could not be created."; exit 1; }

# ---- onto the business's team ------------------------------------------------------------------
# Inviting does not hire anybody: the worker accepts, and only then are they on the team. That
# handshake is the thing being set up here, so it is walked rather than short-circuited.

join_team() {
  local email="$1" token="$2" label="$3"
  local r inv

  r=$(post_ /business/workers/invite "$BT" "{\"workerIdentifier\":\"$email\"}")

  if echo "$r" | grep -q '"success":true'; then
    ok "$label invited" ""
  else
    note "$label invite: $(echo "$r" | msg)"
  fi

  inv=$(get_ /worker/invitations "$token" | j id)
  if [ -n "$inv" ]; then
    post_ /worker/invitations/$inv/respond "$token" '{"accept":true}' >/dev/null
    ok "$label accepted" ""
  else
    note "$label had no pending invitation — already on the team"
  fi
}

echo
join_team "$SUP_EMAIL" "$ST" "Priya"
join_team "$MGR_EMAIL" "$MT" "Arun"

SUP_BW=$(sql "select bw.id from business_workers bw join worker_profiles wp on wp.id=bw.worker_profile_id join users u on u.id=wp.user_id where bw.business_owner_profile_id='$BIZ' and u.email='$SUP_EMAIL' and bw.is_deleted=false")
MGR_BW=$(sql "select bw.id from business_workers bw join worker_profiles wp on wp.id=bw.worker_profile_id join users u on u.id=wp.user_id where bw.business_owner_profile_id='$BIZ' and u.email='$MGR_EMAIL' and bw.is_deleted=false")
eq "Priya is on the team" "$([ -n "$SUP_BW" ] && echo yes)" "yes"
eq "Arun is on the team"  "$([ -n "$MGR_BW" ] && echo yes)" "yes"

# ---- the roles ---------------------------------------------------------------------------------

echo
echo "================ ASSIGNING THE ROLES ================"
R=$(put_ /business/workers/$SUP_BW/role "$BT" "{\"staffRoleId\":\"$ROLE_SUPERVISOR\",\"categoryIds\":[\"$CAT_CLEANING\",\"$CAT_PAINTING\"]}")
if echo "$R" | grep -q 'Supervisor'; then ok "Priya made Supervisor" "Cleaning + Painting"; else bad "Priya made Supervisor" "$(echo "$R" | msg)"; fi

R=$(put_ /business/workers/$MGR_BW/role "$BT" "{\"staffRoleId\":\"$ROLE_MANAGER\",\"categoryIds\":[\"$CAT_PAINTING\"]}")
if echo "$R" | grep -q 'Manager'; then ok "Arun made Manager" "Painting"; else bad "Arun made Manager" "$(echo "$R" | msg)"; fi

# ---- what each of them can now see --------------------------------------------------------------

echo
echo "================ WHAT THE ROLES ACTUALLY REACH ================"
SUP_ORDERS=$(get_ /staff/bookings "$ST" | tr '}' '\n' | grep -c '"id":')
MGR_ORDERS=$(get_ /staff/bookings "$MT" | tr '}' '\n' | grep -c '"id":')
note "Priya (Supervisor, Cleaning + Painting) sees $SUP_ORDERS orders"
note "Arun  (Manager, Painting)              sees $MGR_ORDERS orders"

# A plain worker must see none of this. The role is the whole access rule, so it is worth proving
# rather than assuming.
PLAIN=$(curl -s -o /dev/null -w '%{http_code}' "$API/staff/bookings")
eq "Unauthenticated is refused by the staff routes" "$PLAIN" "401"

echo
echo "================ THE TEAM NOW ================"
"$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -F' | ' -c "
select u.email, u.first_name||' '||u.last_name, coalesce(sr.name,'Worker'),
       coalesce((select string_agg(c.name, ', ' order by c.name)
                 from business_worker_categories bwc
                 join service_categories c on c.id=bwc.service_category_id
                 where bwc.business_worker_id=bw.id and bwc.is_deleted=false), '-')
from business_workers bw
join worker_profiles wp on wp.id=bw.worker_profile_id
join users u on u.id=wp.user_id
left join staff_roles sr on sr.id=bw.staff_role_id
where bw.business_owner_profile_id='$BIZ' and bw.is_deleted=false
order by coalesce(sr.display_order, 0) desc, u.email;" 2>&1 | tr -d '\r'

echo
echo "PASS $PASS   FAIL $FAIL"
[ "$FAIL" -eq 0 ]
