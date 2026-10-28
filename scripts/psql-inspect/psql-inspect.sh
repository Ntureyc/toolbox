#!/usr/bin/env bash
# Universal PostgreSQL diagnostics and health inspection.
#
# Usage:
#   scripts/psql-inspect.sh [database-url]
#
# Inspects connection stats, database size, largest tables, cache hit ratios,
# long-running queries, and dead tuple bloat.
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
  psql "$DB" -X -c "$1"
}

echo "== database overview =="
q "
  select current_database() as database,
         pg_size_pretty(pg_database_size(current_database())) as size,
         version() as pg_version;
"

echo
echo "== active connections by state =="
q "
  select state,
         count(*) as connections
  from pg_stat_activity
  where datname = current_database()
  group by state
  order by count(*) desc;
"

echo
echo "== cache hit ratio =="
q "
  select
    sum(heap_blks_hit) / nullif(sum(heap_blks_hit) + sum(heap_blks_read), 0) * 100 as cache_hit_pct
  from pg_statio_user_tables;
"

echo
echo "== top 10 largest tables =="
q "
  select relname as table_name,
         pg_size_pretty(pg_total_relation_size(relid)) as total_size,
         pg_size_pretty(pg_relation_size(relid)) as data_size,
         pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) as index_size
  from pg_catalog.pg_statio_user_tables
  order by pg_total_relation_size(relid) desc
  limit 10;
"

echo
echo "== long-running queries (> 15 seconds) =="
q "
  select pid,
         now() - query_start as duration,
         state,
         left(query, 80) as query_preview
  from pg_stat_activity
  where datname = current_database()
    and state != 'idle'
    and (now() - query_start) > interval '15 seconds'
  order by duration desc;
"

echo
echo "== dead tuples / tables needing vacuum =="
q "
  select relname as table_name,
         n_live_tup as live_rows,
         n_dead_tup as dead_rows,
         round(n_dead_tup * 100.0 / nullif(n_live_tup + n_dead_tup, 0), 1) as dead_pct,
         last_vacuum,
         last_autovacuum
  from pg_stat_user_tables
  where n_dead_tup > 1000
  order by n_dead_tup desc
  limit 5;
"

echo
echo "== lock conflicts =="
q "
  select blocked_locks.pid as blocked_pid,
         blocking_locks.pid as blocking_pid,
         blocked_activity.query as blocked_statement,
         blocking_activity.query as current_statement_in_blocking_process
  from pg_catalog.pg_locks blocked_locks
  join pg_catalog.pg_stat_activity blocked_activity on blocked_activity.pid = blocked_locks.pid
  join pg_catalog.pg_locks blocking_locks
    on blocking_locks.locktype = blocked_locks.locktype
   and blocking_locks.database is not distinct from blocked_locks.database
   and blocking_locks.relation is not distinct from blocked_locks.relation
   and blocking_locks.page is not distinct from blocked_locks.page
   and blocking_locks.tuple is not distinct from blocked_locks.tuple
   and blocking_locks.virtualxid is not distinct from blocked_locks.virtualxid
   and blocking_locks.transactionid is not distinct from blocked_locks.transactionid
   and blocking_locks.classid is not distinct from blocked_locks.classid
   and blocking_locks.objid is not distinct from blocked_locks.objid
   and blocking_locks.objsubid is not distinct from blocked_locks.objsubid
   and blocking_locks.pid != blocked_locks.pid
  join pg_catalog.pg_stat_activity blocking_activity on blocking_activity.pid = blocking_locks.pid
  where not blocked_locks.granted;
"

echo "inspection complete"
