#!/usr/bin/env bash
# The numbers I want to see first thing in the morning.
#
#   psql-daily-report.sh [database-url]
set -euo pipefail

DB=${1:-${DATABASE_URL:-}}
if [ -z "$DB" ]; then
  echo "usage: $0 <database-url>" >&2
  exit 2
fi

q() {
  psql "$DB" -X -q -c "$1"
}

echo "== orders today =="
q "
  select count(*) as orders,
         coalesce(sum(amount), 0) as gross,
         coalesce(sum(case when status = 'DELIVERED' then amount else 0 end), 0) as delivered_value
  from "order"
  where created_at >= date_trunc('day', now());
"

echo "== orders by status =="
q "
  select status, count(*), coalesce(sum(amount), 0) as value
  from "order"
  where created_at >= now() - interval '7 days'
  group by status
  order by count(*) desc;
"

echo "== eps payments by state (7 days) =="
q "
  select status, count(*), coalesce(sum(amount), 0) as value
  from eps_payment
  where created_at >= now() - interval '7 days'
  group by status
  order by count(*) desc;
"

echo "== stuck eps payments =="
q "
  select count(*) as pending_older_than_30m
  from eps_payment
  where status in ('INITIATED', 'PENDING')
    and updated_at < now() - interval '30 minutes';
"

echo "== new users (7 days) =="
q "
  select count(*) as new_users
  from "user"
  where "createdAt" >= now() - interval '7 days';
"

echo "== failed logins (24h) =="
q "
  select count(*) as failed_logins
  from audit_log
  where action = 'LOGIN_FAILED'
    and "createdAt" >= now() - interval '24 hours';
"

echo "== top referrers (7 days) =="
q "
  select coalesce(source, 'direct') as source, count(*)
  from "order"
  where created_at >= now() - interval '7 days'
  group by 1
  order by 2 desc
  limit 10;
"

echo
echo "done"
