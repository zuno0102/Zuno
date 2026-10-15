#!/usr/bin/env bash
# The app owner building the catalogue.
#
# Before this, a new kind of work could only be added by hand-writing a migration — which is how
# "Acrylic painting" got in, and why a business could not list catering work at all. These
# endpoints let the app owner add any new type without a developer.
#
# What this pins:
#   * a super admin can add a category and sub-categories under it
#   * a business owner cannot — this is the app owner's catalogue, not theirs
#   * slugs are worked out from the name, and clashes are refused with a readable sentence
#   * the same sub-category name IS allowed under two different categories
#   * a sub-category cannot be moved to another category
#   * hiding a category takes it out of the customer-facing list but breaks nothing:
#     the businesses already using it keep working
#   * the existing 8 categories and 49 sub-categories are untouched
API=http://localhost:5056/api/v1
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-90; }

ok()  { PASS=$((PASS+1)); printf 'PASS  %-54s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-54s %s\n' "$1" "$2"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }
has_id()   { if echo "$2" | grep -q '"id"'; then ok "$1" "$(echo "$2" | j name)"; else bad "$1" "$(echo "$2" | msg)"; fi; }
want_fail() { if echo "$2" | grep -q '"id"'; then bad "$1" "it was accepted"; else ok "$1" "$(echo "$2" | msg)"; fi; }

login() {
  curl -s -X POST $API/auth/login -H 'Content-Type: application/json' \
    -d "{\"emailOrPhone\":\"$1\",\"password\":\"$2\"}"
}
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
post_() { curl -s -X POST "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "${3:-\{\}}"; }
put_()  { curl -s -X PUT  "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "${3:-\{\}}"; }
get_()  { curl -s "$API$1" -H "Authorization: Bearer $2"; }
code_() { curl -s -o /dev/null -w '%{http_code}' -X "$1" "$API$2" -H "Authorization: Bearer $3" -H 'Content-Type: application/json' -d "${4:-\{\}}"; }

echo "================ SETUP ================"
AT=$(login admin@zuno.local 'Admin@12345' | j accessToken)
if [ -z "$AT" ]; then echo "super admin login failed"; exit 1; fi
ok "Signed in as the app owner" "admin@zuno.local"

BT=$(reg Boss "cat_b$S@zuno.local" BusinessOwner | j accessToken)
if [ -z "$BT" ]; then echo "business registration failed (rate limit?)"; exit 1; fi
ok "Registered a business to compare against" "cat_b$S@zuno.local"

BEFORE_CATS=$(sql "select count(*) from service_categories where is_deleted=false")
BEFORE_SUBS=$(sql "select count(*) from service_sub_categories where is_deleted=false")
ok "Catalogue before" "$BEFORE_CATS categories, $BEFORE_SUBS sub-categories"

echo
echo "==== 1. ONLY THE APP OWNER MAY TOUCH THE CATALOGUE ===="
eq "A business owner is refused (403)" \
   "$(code_ POST /admin/catalog/categories "$BT" '{"name":"Sneaky","displayOrder":99,"isActive":true}')" "403"
eq "So is a signed-out caller (401)" \
   "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API/admin/catalog/categories" -H 'Content-Type: application/json' -d '{"name":"Sneaky"}')" "401"
eq "...and nothing was created" "$(sql "select count(*) from service_categories where name='Sneaky'")" "0"

echo
echo "==== 2. THE APP OWNER ADDS A CATEGORY ===="
CAT=$(post_ /admin/catalog/categories "$AT" "{\"name\":\"Catering $S\",\"description\":\"Food for events\",\"displayOrder\":20,\"isActive\":true}")
has_id "Category added" "$CAT"
CATID=$(echo "$CAT" | j id)
eq "Slug worked out from the name" "$(echo "$CAT" | j slug)" "catering-$S"
eq "Stored in the database"        "$(sql "select name from service_categories where id='$CATID'")" "Catering $S"
eq "It starts with no services"    "$(echo "$CAT" | grep -o '"serviceCount":[0-9]*' | cut -d: -f2)" "0"
want_fail "A duplicate name is refused" \
   "$(post_ /admin/catalog/categories "$AT" "{\"name\":\"Catering $S\",\"displayOrder\":21,\"isActive\":true}")"
want_fail "A name with no letters is refused" \
   "$(post_ /admin/catalog/categories "$AT" '{"name":"!!!","displayOrder":22,"isActive":true}')"

echo
echo "==== 3. SUB-CATEGORIES UNDER IT ===="
for n in "Wedding catering" "Holy communion catering" "House warming catering" "Engagement catering"; do
  R=$(post_ "/admin/catalog/categories/$CATID/sub-categories" "$AT" "{\"name\":\"$n\",\"displayOrder\":1,\"isActive\":true}")
  has_id "Added: $n" "$R"
done
eq "Four sub-categories under it" "$(sql "select count(*) from service_sub_categories where service_category_id='$CATID' and is_deleted=false")" "4"
want_fail "A duplicate inside the same category is refused" \
   "$(post_ "/admin/catalog/categories/$CATID/sub-categories" "$AT" '{"name":"Wedding catering","displayOrder":9,"isActive":true}')"

# The rule the database index already encodes: "water tank cleaning" genuinely belongs under both
# Plumbing and Cleaning, so the same name under a DIFFERENT category must be allowed.
#
# Named per-run rather than reusing "Wedding catering": this script is expected to be run more than
# once, and a fixed name left behind by the previous run trips the duplicate rule it is not testing.
PAINTID=$(sql "select id from service_categories where slug='painting' and is_deleted=false")
SHARED="Shared name $S"
R=$(post_ "/admin/catalog/categories/$CATID/sub-categories" "$AT" "{\"name\":\"$SHARED\",\"displayOrder\":60,\"isActive\":true}")
has_id "A uniquely named sub-category under Catering" "$R"
R=$(post_ "/admin/catalog/categories/$PAINTID/sub-categories" "$AT" "{\"name\":\"$SHARED\",\"displayOrder\":60,\"isActive\":true}")
has_id "The same name under a different category IS allowed" "$R"
STRAY=$(echo "$R" | j id)

echo
echo "==== 4. A SUB-CATEGORY CANNOT CHANGE CATEGORY ===="
want_fail "Moving it to another category is refused" \
   "$(put_ "/admin/catalog/sub-categories/$STRAY" "$AT" "{\"serviceCategoryId\":\"$CATID\",\"name\":\"$SHARED\",\"displayOrder\":60,\"isActive\":true}")"
eq "...and it did not move" "$(sql "select service_category_id='$PAINTID' from service_sub_categories where id='$STRAY'")" "t"
# Hide the one raised under Painting only to prove that rule, so it does not clutter the catalogue.
put_ "/admin/catalog/sub-categories/$STRAY" "$AT" "{\"serviceCategoryId\":\"$PAINTID\",\"name\":\"$SHARED\",\"displayOrder\":60,\"isActive\":false}" >/dev/null

echo
echo "==== 5. RENAMING KEEPS EVERYTHING ATTACHED ===="
R=$(put_ "/admin/catalog/categories/$CATID" "$AT" "{\"name\":\"Catering & events $S\",\"displayOrder\":20,\"isActive\":true}")
has_id "Renamed" "$R"
eq "New slug follows the new name" "$(echo "$R" | j slug)" "catering-events-$S"
# Five: the four catering ones plus the uniquely-named one raised for the cross-category test.
eq "Sub-categories are still attached" "$(sql "select count(*) from service_sub_categories where service_category_id='$CATID' and is_deleted=false")" "5"

echo
echo "==== 6. HIDING TAKES IT OUT OF THE CUSTOMER LIST, AND BREAKS NOTHING ===="
# A real service priced under the category, so hiding has something to threaten.
DIST=$(sql "select id from districts where is_deleted=false limit 1")
SUBID=$(sql "select id from service_sub_categories where service_category_id='$CATID' and is_deleted=false order by name limit 1")
sql "update business_owner_profiles set verification_status=1, verified_at=now() where user_id=(select id from users where email='cat_b$S@zuno.local')" >/dev/null
SVC=$(post_ /business/services "$BT" "{\"serviceCategoryId\":\"$CATID\",\"name\":\"Wedding feast\",\"priceType\":\"Fixed\",\"price\":50000,\"requiredWorkerCount\":20,\"districtIds\":[\"$DIST\"]}")
has_id "A business lists a service under it" "$SVC"
SVCID=$(echo "$SVC" | j id)

eq "Customers can see the category" \
   "$(curl -s $API/service-categories | tr '{' '\n' | grep -c "\"id\":\"$CATID\"")" "1"

R=$(put_ "/admin/catalog/categories/$CATID" "$AT" "{\"name\":\"Catering & events $S\",\"displayOrder\":20,\"isActive\":false}")
has_id "Hidden" "$R"
eq "Customers no longer see it" \
   "$(curl -s $API/service-categories | tr '{' '\n' | grep -c "\"id\":\"$CATID\"")" "0"
# The point of hiding rather than deleting.
eq "The row is still there, not deleted" "$(sql "select is_deleted from service_categories where id='$CATID'")" "f"
eq "The business's service still exists" "$(sql "select count(*) from business_services where id='$SVCID' and is_deleted=false")" "1"
eq "...and the business can still see it" \
   "$(get_ /business/services "$BT" | tr '{' '\n' | grep -c "\"id\":\"$SVCID\"")" "1"
# And it can be brought back — which is the only reason the admin list shows hidden rows.
eq "The app owner still sees it in the catalogue" \
   "$(get_ /admin/catalog/categories "$AT" | tr '{' '\n' | grep -c "\"id\":\"$CATID\"")" "1"
R=$(put_ "/admin/catalog/categories/$CATID" "$AT" "{\"name\":\"Catering & events $S\",\"displayOrder\":20,\"isActive\":true}")
has_id "Brought back" "$R"
eq "Customers see it again" \
   "$(curl -s $API/service-categories | tr '{' '\n' | grep -c "\"id\":\"$CATID\"")" "1"

echo
echo "==== 7. THE EXISTING CATALOGUE IS UNTOUCHED ===="
eq "The 8 shipped categories are all still there" \
   "$(sql "select count(*) from service_categories where slug in ('plumbing','electrical','cleaning','carpentry','painting','appliance-repair','pest-control','beauty-wellness') and is_deleted=false and is_active=true")" "8"
eq "Acrylic painting is still there" \
   "$(sql "select count(*) from service_sub_categories where slug='acrylic-painting' and is_deleted=false")" "1"
eq "Nothing was deleted"  "$(sql "select count(*) from service_categories where is_deleted=true")" "0"

echo
echo "================ $PASS passed, $FAIL failed ================"
[ "$FAIL" -eq 0 ]
