#!/usr/bin/env bash
# Job invitations — a business picking a named worker for one specific post, through the real
# endpoint: POST /business/hiring-posts/{id}/invite. The application lands in Confirmed, which is
# the offer state, so the worker answers it with the Accept / Decline the app actually shows.
#
# Distinct from seed-worker-invitations.sh, which invites somebody onto a business's permanent
# roster and has no job behind it.
#
# The posts are read from the database rather than from the business's own list, because that list
# is newest-first and this data is mostly past events — an invitation onto a day that has gone is
# refused by the server, correctly, and would seed nothing.
API=http://127.0.0.1:5056/api/v1
PSQL="${PSQL:-psql}"
: "${PGPASSWORD:?set PGPASSWORD to your Postgres password first}"
PW=E2e@12345
OWNER=${OWNER:-owner@zuno.local}
WORKER=${1:-worker@zuno.local}

sql() { "$PSQL" -h 127.0.0.1 -p 5432 -U postgres -d "${ZUNO_DB:-zuno}" -t -A -c "$1" 2>/dev/null | tr -d '\r'; }

TOKEN=$(curl -s -X POST "$API/auth/login" -H 'Content-Type: application/json' \
  -d "{\"emailOrPhone\":\"$OWNER\",\"password\":\"$PW\"}" |
  grep -o '"accessToken":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "Could not sign in as $OWNER."
  exit 1
fi

POSTS=$(sql "
  SELECT p.id
  FROM hiring_posts p
  JOIN business_owner_profiles b ON b.id = p.business_owner_profile_id
  JOIN users u ON u.id = b.user_id
  WHERE u.email = '$OWNER' AND p.hiring_post_status = 1 AND p.event_date > now()
  ORDER BY p.event_date
  LIMIT 5;")

echo "Inviting $WORKER onto open jobs from $OWNER:"
for id in $POSTS; do
  body=$(curl -s -X POST "$API/business/hiring-posts/$id/invite" \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
    -d "{\"workerIdentifier\":\"$WORKER\"}")

  title=$(echo "$body" | grep -o '"title":"[^"]*"' | head -1 | cut -d'"' -f4)
  if echo "$body" | grep -q '"success":true'; then
    printf '  invited  %s\n' "${title:-$id}"
  else
    printf '  skipped  %s\n' \
      "$(echo "$body" | grep -o '"message":"[^"]*"' | head -1 | cut -d'"' -f4)"
  fi
done

echo
echo "On the worker's Invitations tab now:"
WT=$(curl -s -X POST "$API/auth/login" -H 'Content-Type: application/json' \
  -d "{\"emailOrPhone\":\"$WORKER\",\"password\":\"$PW\"}" |
  grep -o '"accessToken":"[^"]*"' | head -1 | cut -d'"' -f4)
curl -s "$API/worker/hiring-posts/offers" -H "Authorization: Bearer $WT" |
  grep -o '"title":"[^"]*"' | cut -d'"' -f4 | sed 's/^/  /'
