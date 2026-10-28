#!/usr/bin/env bash
# Job invitations for the worker's Invitations tab, created the way a business actually creates them:
# POST /business/workers/invite, signed in as the business owner, against a real worker account.
#
# Nothing is written straight into the tables, so what appears on screen took the real path and the
# Accept / Decline buttons work on it afterwards.
#
# Safe to re-run. A worker already invited to, or already working for, a business is refused by the
# server with a plain message, which this reports rather than treating as a failure.
API=http://127.0.0.1:5056/api/v1
PW=E2e@12345
WORKER=${1:-worker@zuno.local}

# The login endpoint allows 5 attempts a minute per IP, and every invite costs one.
RATE_LIMIT_PAUSE=13

login() {
  curl -s -X POST "$API/auth/login" -H 'Content-Type: application/json' \
    -d "{\"emailOrPhone\":\"$1\",\"password\":\"$PW\"}" |
    grep -o '"accessToken":"[^"]*"' | head -1 | cut -d'"' -f4
}

invite() { # <ownerEmail> <businessName>
  local token body
  token=$(login "$1")

  if [ -z "$token" ]; then
    printf '  %-16s SKIPPED — could not sign in as %s\n' "$2" "$1"
    return
  fi

  body=$(curl -s -X POST "$API/business/workers/invite" \
    -H "Authorization: Bearer $token" -H 'Content-Type: application/json' \
    -d "{\"workerIdentifier\":\"$WORKER\"}")

  if echo "$body" | grep -q '"success":true'; then
    printf '  %-16s invited\n' "$2"
  else
    printf '  %-16s %s\n' "$2" \
      "$(echo "$body" | grep -o '"message":"[^"]*"' | head -1 | cut -d'"' -f4)"
  fi

  sleep "$RATE_LIMIT_PAUSE"
}

echo "Inviting $WORKER:"
invite boss1789030368@zuno.local "boss Tester"
invite clb1789109424@zuno.local  "Clash B"
invite dash1789367972@zuno.local "Dash B"
invite dbg1789107569@zuno.local  "Dbg T"
invite mb1789109456@zuno.local   "M B"

echo
echo "Pending on the Invitations tab now:"
curl -s "$API/worker/invitations" -H "Authorization: Bearer $(login "$WORKER")" |
  grep -o '"businessName":"[^"]*"' | cut -d'"' -f4 | sed 's/^/  /'
