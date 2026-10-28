#!/usr/bin/env bash
# A business setting its profile picture.
#
# The feature did not exist before: the column was there, the avatar rendered whatever URL it
# found, and nothing ever wrote one — 0 of 124 profiles had a picture. This pins the new slice.
#
# What this pins:
#   * uploading returns the profile with a root-relative URL, and the file is actually served
#   * re-uploading replaces the picture rather than accumulating files
#   * a PNG after a JPEG does not leave the old file behind to be served instead
#   * editing the profile does NOT wipe the picture — the trap that made this worth a test,
#     since the edit form posts back whatever copy it loaded
#   * removing clears the URL and deletes the file
#   * the obvious refusals: empty, oversized, and wrong content type
API=${API:-http://localhost:5056/api/v1}
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
S=$(date +%s)
WORK=$(mktemp -d)
PASS=0; FAIL=0

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }
j()   { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
msg() { tr ',' '\n' | grep '"message"' | head -1 | cut -d'"' -f4 | cut -c1-90; }

ok()  { PASS=$((PASS+1)); printf 'PASS  %-52s %s\n' "$1" "$2"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %-52s %s\n' "$1" "$2"; }
want_ok()   { if echo "$2" | grep -q '"success":true'; then ok "$1" "$3"; else bad "$1" "$(echo "$2" | msg)"; fi; }
want_fail() { if echo "$2" | grep -q '"success":true'; then bad "$1" "it was accepted"; else ok "$1" "$(echo "$2" | msg)"; fi; }
eq()        { if [ "$2" = "$3" ]; then ok "$1" "$2"; else bad "$1" "got '$2' expected '$3'"; fi; }

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
# Run from inside the work directory with a bare filename. curl here is the Windows build and
# cannot resolve an MSYS path like /tmp/tmp.X/logo.jpg — it fails to send anything at all, which
# looks exactly like a server refusal until you notice the status is 000.
upload() { (cd "$WORK" && curl -s -X POST "$API/business/profile/logo" \
             -H "Authorization: Bearer $1" -F "file=@$2;type=$3"); }
logo_of() { sql "select coalesce(logo_url,'') from business_owner_profiles where id='$BIZ'"; }

# Asks for a file as a signed-in caller. An anonymous request for a path that matches nothing is
# answered 401 by the deny-by-default policy, not 404 — it covers unmatched requests as well as
# endpoints — so "is the file gone?" has to be asked with a token or the answer is ambiguous.
served() { curl -s -o /dev/null -w '%{http_code}' "${API%/api/v1}$1" -H "Authorization: Bearer $BT"; }

# A real 1x1 JPEG and a real 1x1 PNG, so the served bytes are genuinely an image.
printf '%s' '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==' | base64 -d > "$WORK/logo.jpg"
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' | base64 -d > "$WORK/logo.png"
head -c 6000000 /dev/urandom > "$WORK/huge.jpg"
: > "$WORK/empty.jpg"

echo "================ SETUP ================"
BT=$(reg Boss "logo_b$S@zuno.local" BusinessOwner | j accessToken)
if [ -z "$BT" ]; then echo "registration failed (rate limit?)"; exit 1; fi
BIZ=$(sql "select b.id from business_owner_profiles b join users u on u.id=b.user_id where u.email='logo_b$S@zuno.local'")
ok "Registered a business" "logo_b$S@zuno.local"
eq "Starts with no picture" "$(logo_of)" ""

echo
echo "==== 1. UPLOADING ONE ===="
R=$(upload "$BT" "logo.jpg" image/jpeg)
want_ok "Upload accepted" "$R" ""
URL=$(echo "$R" | j logoUrl)
case "$URL" in
  /uploads/businesses/$BIZ/logo.jpg) ok "URL is root-relative and owned" "$URL";;
  *) bad "URL is root-relative and owned" "got '$URL'";;
esac
eq "Stored on the profile" "$(logo_of)" "$URL"
eq "And the file is actually served" "$(curl -s -o /dev/null -w '%{http_code}' "${API%/api/v1}$URL")" "200"
eq "...as an image"                  "$(curl -s -o /dev/null -w '%{content_type}' "${API%/api/v1}$URL")" "image/jpeg"

echo
echo "==== 2. REPLACING IT ===="
# A PNG over a JPEG is the case that leaves litter if only the matching extension is cleared:
# the old logo.jpg would still sit there, and nothing says which of the two is current.
R2=$(upload "$BT" "logo.png" image/png)
want_ok "Re-upload accepted" "$R2" ""
URL2=$(echo "$R2" | j logoUrl)
eq "Now points at the PNG" "$URL2" "/uploads/businesses/$BIZ/logo.png"
eq "The old JPEG is gone"  "$(served "$URL")" "404"
eq "Exactly one file on disk" "$(ls "/c/Beaulin Shajil/Projects/MobileApps/Zuno/backend/Zuno_service/src/Zuno.Api/wwwroot/uploads/businesses/$BIZ" 2>/dev/null | wc -l | tr -d ' ')" "1"

echo
echo "==== 3. EDITING THE PROFILE MUST NOT WIPE IT ===="
# The trap. The edit form posts the whole profile back, including whatever logoUrl it loaded —
# which for a form opened before the upload is null. Renaming your business must not erase your
# picture, so the update handler no longer writes the field at all.
want_ok "Renamed the business" "$(curl -s -X PUT $API/business/profile -H "Authorization: Bearer $BT" \
  -H 'Content-Type: application/json' -d '{"businessName":"Renamed Ltd","logoUrl":null}')" ""
eq "Picture survived the rename" "$(logo_of)" "$URL2"
eq "Name did change"             "$(sql "select business_name from business_owner_profiles where id='$BIZ'")" "Renamed Ltd"

echo
echo "==== 4. REMOVING IT ===="
want_ok "Remove accepted" "$(curl -s -X DELETE $API/business/profile/logo -H "Authorization: Bearer $BT")" ""
eq "Cleared on the profile"   "$(logo_of)" ""
eq "And the file is gone"     "$(served "$URL2")" "404"

echo
echo "==== 5. WHAT IT REFUSES ===="
want_fail "An empty file"        "$(upload "$BT" "empty.jpg" image/jpeg)"
want_fail "Something over 5MB"   "$(upload "$BT" "huge.jpg" image/jpeg)"
want_fail "A PDF wearing a .jpg" "$(upload "$BT" "logo.jpg" application/pdf)"
eq "Nothing was stored by any of those" "$(logo_of)" ""
# Signed out entirely: the picture is per-business, so this must never be open.
UNAUTH=$(cd "$WORK" && curl -s -o /dev/null -w '%{http_code}' -X POST "$API/business/profile/logo" \
  -F "file=@logo.jpg;type=image/jpeg")
if [ "$UNAUTH" = "401" ] || [ "$UNAUTH" = "403" ]; then ok "Anonymous upload refused" "$UNAUTH"; else bad "Anonymous upload refused" "got $UNAUTH"; fi

rm -rf "$WORK"
echo
echo "================ $PASS passed, $FAIL failed ================"
[ "$FAIL" -eq 0 ]
