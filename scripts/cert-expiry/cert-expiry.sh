#!/usr/bin/env bash
# Show how many days are left on every certificate certbot manages.
# Warn at 30 days, fail at 7.
set -euo pipefail

WARN_DAYS=${WARN_DAYS:-30}
FAIL_DAYS=${FAIL_DAYS:-7}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  echo "Usage: $0 [cert-dir]"
  echo "Lists certificate expiry days for Let's Encrypt certificates (default: /etc/letsencrypt/live)."
  echo "Options/Env: WARN_DAYS=30, FAIL_DAYS=7"
  exit 0
fi

conf=${1:-/etc/letsencrypt/live}

if [ ! -d "$conf" ]; then
  echo "no certificate directory at $conf"
  exit 0
fi

status=0

printf '%-42s %8s %8s\n' "DOMAIN" "DAYS" "EXPIRES"
printf '%-42s %8s %8s\n' "-------" "----" "-------"

for d in "$conf"/*/; do
  [ -d "$d" ] || continue
  domain=$(basename "$d")
  cert="$d/fullchain.pem"
  [ -f "$cert" ] || continue

  end=$(openssl x509 -enddate -noout -in "$cert" 2>/dev/null | cut -d= -f2)
  [ -n "$end" ] || continue

  end_epoch=$(date -d "$end" +%s 2>/dev/null || echo "")
  [ -n "$end_epoch" ] || continue

  now=$(date +%s)
  days=$(( (end_epoch - now) / 86400 ))

  printf '%-42s %8s %8s\n' "$domain" "$days" "$end"

  if [ "$days" -lt "$FAIL_DAYS" ]; then
    echo "    EXPIRING SOON - renew now" >&2
    status=1
  elif [ "$days" -lt "$WARN_DAYS" ]; then
    echo "    renew within $WARN_DAYS days" >&2
  fi
done

exit "$status"
