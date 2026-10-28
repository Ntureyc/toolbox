#!/usr/bin/env bash
# Show which Prisma migrations are applied and which are not.
# Read-only: it never runs a migration.
#
# Usage:
#   scripts/migrate-status.sh [app-dir]
#
# Defaults to the current working directory.
set -euo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,/^set -euo pipefail/p' "$0" | grep -v '^set' | sed 's/^# //' | sed 's/^#//'
  exit 0
fi

APP_DIR=${1:-.}
DRY_RUN=${DRY_RUN:-0}

if [ ! -d "$APP_DIR" ]; then
  echo "directory $APP_DIR does not exist" >&2
  exit 1
fi

cd "$APP_DIR"

if [ ! -f prisma/schema.prisma ] && [ ! -f schema.prisma ]; then
  echo "no schema.prisma found in $APP_DIR or $APP_DIR/prisma" >&2
  echo "usage: $0 [app-dir]" >&2
  exit 1
fi

echo "== prisma migrate status =="
if [ "$DRY_RUN" = "1" ]; then
  echo "dry run - would run 'prisma migrate status'"
else
  npx prisma migrate status || true
fi

echo
echo "== recent migration history =="
if [ -n "${DATABASE_URL:-}" ] && command -v psql >/dev/null 2>&1; then
  psql "$DATABASE_URL" -c "
    select migration_name,
           to_char(started_at,  'YYYY-MM-DD HH24:MI') as started,
           to_char(finished_at, 'YYYY-MM-DD HH24:MI') as finished,
           left(coalesce(logs,''), 60) as logs
    from _prisma_migrations
    order by started_at desc
    limit 10;
  " 2>/dev/null || echo "  (could not query _prisma_migrations)"
else
  echo "  (set DATABASE_URL to query the history from Postgres directly)"
fi

echo
echo "== migrations on disk =="
if [ -d prisma/migrations ]; then
  count=$(find prisma/migrations -mindepth 1 -maxdepth 1 -type d | wc -l)
  echo "  $count migration(s) found in prisma/migrations/"
else
  echo "  (no prisma/migrations directory)"
fi
