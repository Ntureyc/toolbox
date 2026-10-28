#!/usr/bin/env bash
# Find pending or initiated payments sitting in a non-final state.
#
# Usage:
#   scripts/eps-reconcile.sh [database-url] [older-than-minutes]
#
# Environment variables:
#   PAYMENT_TABLE        Name of payments table (default: payments or eps_payment)
#
# Read-only. Reports anomalies without modifying data.
set -euo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,/^set -euo pipefail/p' "$0" | grep -v '^set' | sed 's/^# //' | sed 's/^#//'
  exit 0
fi

DB_URL=${1:-${DATABASE_URL:-}}
OLDER_THAN=${2:-30}

if [ -z "$DB_URL" ]; then
  echo "usage: $0 <database-url> [older-than-minutes]" >&2
  exit 2
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is not installed" >&2
  exit 1
fi

TABLE="${PAYMENT_TABLE:-}"
if [ -z "$TABLE" ]; then
  for candidate in payments payment eps_payment; do
    has_tbl=$(psql "$DB_URL" -X -t -A -c "select count(*) from information_schema.tables where table_name = '$candidate';" 2>/dev/null || echo 0)
    if [ "${has_tbl:-0}" -gt 0 ]; then
      TABLE="$candidate"
      break
    fi
  done
fi

if [ -z "$TABLE" ]; then
  echo "no payments table found (tried: payments, payment, eps_payment). Set PAYMENT_TABLE=name." >&2
  exit 1
fi

echo "== payments not in a final state in '$TABLE' (older than ${OLDER_THAN}m) =="
psql "$DB_URL" -X -c "
  select id,
         status,
         amount,
         to_char(created_at,  'YYYY-MM-DD HH24:MI') as created,
         to_char(updated_at,  'YYYY-MM-DD HH24:MI') as updated,
         now() - updated_at as age
  from \"$TABLE\"
  where status in ('INITIATED', 'PENDING')
    and updated_at < now() - (interval '1 minute' * $OLDER_THAN)
  order by updated_at asc;
" 2>/dev/null || echo "  (unable to query pending payments on $TABLE)"

echo
echo "== recent failures (check for late callbacks) =="
psql "$DB_URL" -X -c "
  select id,
         status,
         amount,
         to_char(updated_at, 'YYYY-MM-DD HH24:MI') as updated
  from \"$TABLE\"
  where status in ('FAILED', 'CANCELLED')
    and updated_at >= now() - interval '24 hours'
  order by updated_at desc
  limit 10;
" 2>/dev/null || echo "  (unable to query failed payments on $TABLE)"

echo "done"
