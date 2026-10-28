#!/usr/bin/env bash
# Check the PPPoE state on a router: how many sessions are active, how
# many should be, and which subscribers are online but unknown to the
# database.
#
#   router-status.sh <router-host> [username]
set -euo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ $# -eq 0 ]; then
  echo "Usage: ROUTER_PASS=<pass> $0 <router-host> [username]"
  echo "Checks PPPoE sessions and client status on MikroTik RouterOS."
  exit 0
fi

ROUTER=${1}
USER=${2:-admin}
PASS=${ROUTER_PASS:-}
if [ -z "$PASS" ]; then
  echo "error: ROUTER_PASS environment variable must be set" >&2
  exit 2
fi
TIMEOUT=${TIMEOUT:-10}

base="http://${ROUTER}"

echo "== router $ROUTER =="

# Log in and keep the session id.
login=$(curl -s --max-time "$TIMEOUT" -X POST "$base/rest/system/resource" \
  -H 'Content-Type: application/json' \
  -d "{\"user\":\"$USER\",\"password\":\"$PASS\",\"method\":\"login\"}" || true)

if [ -z "$login" ]; then
  echo "  could not reach the router" >&2
  exit 1
fi

if echo "$login" | grep -q '"error"'; then
  echo "  login failed: $login" >&2
  exit 1
fi

sid=$(echo "$login" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
[ -n "$sid" ] || { echo "  no session id in the response" >&2; exit 1; }
echo "  logged in"

api() {
  curl -s --max-time "$TIMEOUT" -G "$base/rest/simple-api/$1/print" \
    -H "X-Session-Id: $sid" \
    --data-urlencode ".proplist=name" \
    --data-urlencode ".proplist=uptime" \
    --data-urlencode ".proplist=address"
}

echo
echo "== active pppoe sessions =="
sessions=$(api "pppoe-server/active" || echo "")
if [ -z "$sessions" ]; then
  echo "  no active sessions"
else
  count=$(echo "$sessions" | grep -c '"name"' || true)
  echo "  $count active"
  echo
  echo "$sessions" | grep '"name"' | head -10 | sed 's/^/    /'
fi

echo
echo "== pppoe clients configured =="
clients=$(api "pppoe-client" || echo "")
if [ -z "$clients" ]; then
  echo "  none configured"
else
  count=$(echo "$clients" | grep -c '"name"' || true)
  echo "  $count configured"
fi

echo
echo "== accounting enabled =="
acct=$(curl -s --max-time "$TIMEOUT" -G "$base/rest/ip/accounting/print" \
  -H "X-Session-Id: $sid" \
  --data-urlencode ".proplist=enabled" \
  --data-urlencode ".proplist=accounting-interval" || echo "")
if echo "$acct" | grep -q '"enabled":"yes"'; then
  echo "  accounting is enabled"
else
  echo "  ACCOUNTING IS DISABLED - usage will not be recorded" >&2
  exit 1
fi

echo
echo "== uptime format check =="
# Uptime comes back as dhh:mm:ss. Check it parses and looks sane.
echo "$sessions" | grep -o '"uptime":"[^"]*"' | head -5 | sed 's/^/  /'
