#!/usr/bin/env bash
# Pictures and video on a service and on its packages — the six media endpoints that had no test.
#
# The one this exists for is section 4. The upload endpoints write the file to disk FIRST and only
# then send the command that checks the service belongs to the caller. The storage layer clears the
# slot before writing, so an upload aimed at somebody else's service id deleted their picture and
# put the caller's in its place, and the ownership error arrived too late to matter. Service ids
# are not secret — a customer browsing sees them — so any signed-in business could do it.
#
# Also pinned: the slot range, the type and size refusals, that replacing does not accumulate
# files, and that removing clears both the row and the file.
API=${API:-http://localhost:5056/api/v1}
HOST=${API%/api/v1}
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
UPLOADS="/c/Beaulin Shajil/Projects/MobileApps/Zuno/backend/Zuno_service/src/Zuno.Api/wwwroot/uploads"
S=$(date +%s)
WORK=$(mktemp -d)
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-90; }

ok()  { PASS=$((PASS+1)); printf 'PASS  %-54s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-54s %s\n' "$1" "$2"; }
want_ok()   { if echo "$2" | grep -q '"success":true'; then ok "$1" "$3"; else bad "$1" "$(echo "$2" | msg)"; fi; }
want_fail() { if echo "$2" | grep -q '"success":true'; then bad "$1" "ACCEPTED — the rule should have refused it"; else ok "$1" "$(echo "$2" | msg)"; fi; }
eq()        { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }
step()      { printf '\n==== %s ====\n' "$1"; }

reg() { curl -s -X POST $API/auth/register -H 'Content-Type: application/json' \
  -d "{\"firstName\":\"$1\",\"lastName\":\"M\",\"email\":\"$2\",\"password\":\"E2e@12345\",\"phoneNumber\":\"9$(shuf -i 100000000-999999999 -n 1)\",\"role\":\"$3\"}"; }
P()  { local b="${3:-{\}}"; curl -s -X POST "$API$1" -H "Authorization: Bearer $2" -H 'Content-Type: application/json' -d "$b"; }
G()  { curl -s "$API$1" -H "Authorization: Bearer $2"; }
DEL(){ curl -s -o /dev/null -w '%{http_code}' -X DELETE "$API$1" -H "Authorization: Bearer $2"; }

# curl here is the Windows build and cannot resolve an MSYS path, so uploads run from inside the
# work directory with a bare filename. A path like /tmp/x/a.jpg sends nothing at all and looks
# exactly like a server refusal until you notice the status is 000.
up() { (cd "$WORK" && curl -s -X POST "$API$1" -H "Authorization: Bearer $2" -F "file=@$3;type=$4"); }

# Asks for a file as a signed-in caller. Anonymously, a path matching nothing answers 401 from the
# deny-by-default policy rather than 404, so "is it gone?" needs a token to be answerable.
served() { curl -s -o /dev/null -w '%{http_code}' "$HOST$1" -H "Authorization: Bearer $2"; }

# Real, tiny files: the server judges an upload by its first bytes, so a text file named .jpg is
# refused (that is what fake.jpg below checks).
printf '%s' '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==' | base64 -d > "$WORK/a.jpg"
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' | base64 -d > "$WORK/b.png"
printf '%s' 'AAAAGGZ0eXBtcDQyAAAAAG1wNDJpc29t' | base64 -d > "$WORK/c.mp4"
printf 'pdf' > "$WORK/fake.jpg"
: > "$WORK/empty.jpg"
head -c 6000000 /dev/urandom > "$WORK/huge.jpg"

echo "=============================================================="
echo " SERVICE AND PACKAGE MEDIA   $(date '+%Y-%m-%d %H:%M')"
echo "=============================================================="

step "0. TWO BUSINESSES AND A SERVICE"
AT=$(reg Owner "media_a$S@zuno.local" BusinessOwner | j accessToken)
BT=$(reg Other "media_b$S@zuno.local" BusinessOwner | j accessToken)
eq "Business A signed up" "$([ -n "$AT" ] && echo yes)" "yes"
eq "Business B signed up" "$([ -n "$BT" ] && echo yes)" "yes"
[ -n "$AT" ] && [ -n "$BT" ] || { echo "ABORTED: sign-up failed"; exit 1; }

BIZ_A=$(sql "select b.id from business_owner_profiles b join users u on u.id=b.user_id where u.email='media_a$S@zuno.local'")
DIST=$(sql "select id from districts limit 1")
CAT=$(sql "select id from service_categories where is_active order by name limit 1")

SVC=$(P /business/services "$AT" "{\"serviceCategoryId\":\"$CAT\",\"name\":\"Media test service\",\"description\":\"d\",\"priceType\":\"Fixed\",\"price\":1000,\"requiredWorkerCount\":1,\"estimatedDurationMinutes\":60,\"districtIds\":[\"$DIST\"]}" | j id)
eq "A created a service" "$([ -n "$SVC" ] && echo yes)" "yes"
[ -n "$SVC" ] || { echo "ABORTED: no service"; exit 1; }

# Read back from the database, not from the response: creating a package answers with the whole
# service, whose own id comes first in the JSON, so picking the first "id" gave the service id and
# every package call then failed with "variant not found".
P /business/services/$SVC/variants "$AT" '{"name":"Package","priceType":"Fixed","price":1500}' >/dev/null
VAR=$(sql "select id from business_service_variants where business_service_id='$SVC' limit 1")
eq "A created a package" "$([ -n "$VAR" ] && echo yes)" "yes"

step "1. PICTURES ON THE SERVICE"
R=$(up "/business/services/$SVC/images/0" "$AT" a.jpg image/jpeg)
want_ok "Slot 0 accepted" "$R" ""
URL0=$(echo "$R" | grep -o '"url":"[^"]*"' | head -1 | cut -d'"' -f4)
eq "...stored under the service"  "$(echo "$URL0" | grep -c "/uploads/services/$SVC/image-0")" "1"
eq "...and the file is served"    "$(served "$URL0" "$AT")" "200"
eq "...and the row is in the database" \
   "$(sql "select count(*) from business_service_media where business_service_id='$SVC' and not is_deleted and media_type=1 and sort_order=0")" "1"

want_ok "Slot 1 accepted"  "$(up "/business/services/$SVC/images/1" "$AT" b.png image/png)" ""
want_ok "Slot 2 accepted"  "$(up "/business/services/$SVC/images/2" "$AT" a.jpg image/jpeg)" ""
eq "Three pictures, three rows" \
   "$(sql "select count(*) from business_service_media where business_service_id='$SVC' and not is_deleted and media_type=1")" "3"

want_fail "Slot 3 refused"  "$(up "/business/services/$SVC/images/3" "$AT" a.jpg image/jpeg)"
want_fail "Slot -1 refused" "$(up "/business/services/$SVC/images/-1" "$AT" a.jpg image/jpeg)"

step "2. REPLACING A PICTURE DOES NOT PILE UP FILES"
R=$(up "/business/services/$SVC/images/0" "$AT" b.png image/png)
want_ok "Slot 0 replaced with a PNG" "$R" ""
URL0B=$(echo "$R" | grep -o '"url":"[^"]*"' | head -1 | cut -d'"' -f4)
eq "...now points at the PNG"   "$(echo "$URL0B" | grep -c 'image-0.png')" "1"
eq "...the old JPEG is gone"    "$(served "$URL0" "$AT")" "404"
eq "...still one row for slot 0" \
   "$(sql "select count(*) from business_service_media where business_service_id='$SVC' and not is_deleted and media_type=1 and sort_order=0")" "1"
eq "...one file per slot on disk" \
   "$(ls "$UPLOADS/services/$SVC" 2>/dev/null | grep -c '^image-')" "3"

step "3. VIDEO, ON THE SERVICE AND ON THE PACKAGE"
R=$(up "/business/services/$SVC/video" "$AT" c.mp4 video/mp4)
want_ok "Service video accepted" "$R" ""
VURL=$(echo "$R" | grep -o '"url":"[^"]*"' | head -1 | cut -d'"' -f4)
eq "...served"                  "$(served "$VURL" "$AT")" "200"
want_fail "A JPEG as the video is refused" "$(up "/business/services/$SVC/video" "$AT" a.jpg image/jpeg)"

want_ok "Package picture accepted" "$(up "/business/services/$SVC/variants/$VAR/images/0" "$AT" a.jpg image/jpeg)" ""
want_ok "Package video accepted"   "$(up "/business/services/$SVC/variants/$VAR/video" "$AT" c.mp4 video/mp4)" ""
eq "Package media sits in its own folder" \
   "$(ls "$UPLOADS/services/$SVC/variants/$VAR" 2>/dev/null | wc -l | tr -d ' ')" "2"

step "4. ANOTHER BUSINESS CANNOT TOUCH IT"
# The point of the whole script. B aims at A's service id. Whatever the answer, A's picture must
# still be on disk afterwards and must still be the picture A uploaded.
BEFORE=$(served "$URL0B" "$AT")
eq "A's slot-0 picture is being served before B tries" "$BEFORE" "200"

want_fail "B cannot upload to A's service"       "$(up "/business/services/$SVC/images/0" "$BT" a.jpg image/jpeg)"
eq        "...A's picture is still served"       "$(served "$URL0B" "$AT")" "200"
eq        "...and A's row is untouched"          "$(sql "select url from business_service_media where business_service_id='$SVC' and not is_deleted and media_type=1 and sort_order=0")" "$URL0B"

want_fail "B cannot upload a video to A's service" "$(up "/business/services/$SVC/video" "$BT" c.mp4 video/mp4)"
eq        "...A's video is still served"           "$(served "$VURL" "$AT")" "200"

want_fail "B cannot upload to A's package"       "$(up "/business/services/$SVC/variants/$VAR/images/0" "$BT" a.jpg image/jpeg)"
eq        "...A's package media survives"        "$(ls "$UPLOADS/services/$SVC/variants/$VAR" 2>/dev/null | wc -l | tr -d ' ')" "2"

eq "B cannot delete A's picture"  "$(DEL "/business/services/$SVC/images/1" "$BT")" "401"
eq "...A's slot 1 is still there" \
   "$(sql "select count(*) from business_service_media where business_service_id='$SVC' and not is_deleted and media_type=1 and sort_order=1")" "1"

step "5. WHAT IT REFUSES"
want_fail "An empty file"            "$(up "/business/services/$SVC/images/1" "$AT" empty.jpg image/jpeg)"
want_fail "Something over the limit" "$(up "/business/services/$SVC/images/1" "$AT" huge.jpg image/jpeg)"
want_fail "A PDF wearing a .jpg"     "$(up "/business/services/$SVC/images/1" "$AT" fake.jpg application/pdf)"
eq "None of those changed slot 1" \
   "$(sql "select count(*) from business_service_media where business_service_id='$SVC' and not is_deleted and media_type=1 and sort_order=1")" "1"
eq "Anonymous upload refused" \
   "$(cd "$WORK" && curl -s -o /dev/null -w '%{http_code}' -X POST "$API/business/services/$SVC/images/0" -F "file=@a.jpg;type=image/jpeg")" "401"

step "6. REMOVING"
eq "Picture removed"        "$(DEL "/business/services/$SVC/images/2" "$AT")" "204"
eq "...row gone"           "$(sql "select count(*) from business_service_media where business_service_id='$SVC' and not is_deleted and media_type=1 and sort_order=2")" "0"
eq "Service video removed"  "$(DEL "/business/services/$SVC/video" "$AT")" "204"
eq "...video row gone"     "$(sql "select count(*) from business_service_media where business_service_id='$SVC' and not is_deleted and media_type=2")" "0"
eq "Package video removed"  "$(DEL "/business/services/$SVC/variants/$VAR/video" "$AT")" "204"

echo
echo "================ $PASS passed, $FAIL failed ================"
rm -rf "$WORK"
[ "$FAIL" -eq 0 ]
