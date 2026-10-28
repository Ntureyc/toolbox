#!/usr/bin/env bash
# High-level database summary and daily activity report.
#
# Usage:
#   scripts/psql-daily-report.sh [database-url]
set -euo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,/^set -euo pipefail/p' "$0" | grep -v '^set' | sed 's/^# //' | sed 's/^#//'
  exit 0
fi

DB="${1:-${DATABASE_URL:-}}"
if [ -z "$DB" ]; then
  echo "usage: $0 <database-url>" >&2
  echo "   or set DATABASE_URL environment variable" >&2
  exit 2
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is not installed" >&2
  exit 1
fi

q() {
  psql "$DB" -X -q -c "$1"
}

table_exists() {
  local tbl="$1"
  local count
  count=$(psql "$DB" -X -t -A -c "select count(*) from information_schema.tables where table_name = '$tbl';" 2>/dev/null || echo 0)
  [ "${count:-0}" -gt 0 ]
}

echo "== database overview =="
q "
  select current_database() as database,
         pg_size_pretty(pg_database_size(current_database())) as size,
         to_char(now(), 'YYYY-MM-DD HH24:MI:SS TZ') as report_time;
"

echo "== active connections =="
q "
  select state, count(*) as count
  from pg_stat_activity
  where datname = current_database()
  group by state;
"

if table_exists "order"; then
  echo "== orders today =="
  q "
    select count(*) as orders,
           coalesce(sum(amount), 0) as gross,
           coalesce(sum(case when status = 'DELIVERED' then amount else 0 end), 0) as delivered_value
    from \"order\"
    where created_at >= date_trunc('day', now());
  "

  echo "== orders by status (last 7 days) =="
  q "
    select status, count(*), coalesce(sum(amount), 0) as value
    from \"order\"
    where created_at >= now() - interval '7 days'
    group by status
    order by count(*) desc;
  "
fi

if table_exists "user"; then
  echo "== new users (last 7 days) =="
  q "
    select count(*) as new_users
    from \"user\"
    where created_at >= now() - interval '7 days';
  " 2>/dev/null || true
fi

if table_exists "payment"; then
  echo "== payments (last 7 days) =="
  q "
    select status, count(*), coalesce(sum(amount), 0) as total
    from payment
    where created_at >= now() - interval '7 days'
    group by status
    order by count(*) desc;
  "
fi

echo "done"
