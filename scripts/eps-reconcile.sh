#!/usr/bin/env bash
# Find EPS payments that have been sitting in a non-final state.
#
#   eps-reconcile.sh [database-url] [older-than-minutes]
#
# Read-only. It reports, it does not change anything.
set -euo pipefail

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

echo "== EPS payments not in a final state (older than ${OLDER_THAN}m) =="
psql "$DB_URL" -X -c "
  select id,
         "orderId",
         status,
         amount,
         to_char(created_at,  'YYYY-MM-DD HH24:MI') as created,
         to_char(updated_at,  'YYYY-MM-DD HH24:MI') as updated,
         now() - updated_at as age
  from eps_payment
  where status in ('INITIATED', 'PENDING')
    and updated_at < now() - (interval '1 minute' * $OLDER_THAN)
  order by updated_at asc;
"

echo
echo "== recent failures (these may still receive a late callback) =="
psql "$DB_URL" -X -c "
  select id,
         "orderId",
         status,
         to_char(updated_at, 'YYYY-MM-DD HH24:MI') as updated,
         left(coalesce(failure_reason, ''), 60) as reason
  from eps_payment
  where status in ('FAILED', 'CANCELLED')
    and updated_at > now() - interval '7 days'
  order by updated_at desc
  limit 20;
"

echo
echo "== payments marked successful more than once (duplicate callbacks) =="
psql "$DB_URL" -X -c "
  select "orderId", count(*) as successful_rows
  from eps_payment
  where status = 'SUCCESS'
  group by "orderId"
  having count(*) > 1;
"

echo
echo "Done. A non-empty first query needs a re-check against the gateway."
echo "A non-empty third query means a callback was applied more than once."
