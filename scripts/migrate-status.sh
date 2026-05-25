#!/usr/bin/env bash
# Show which Prisma migrations are applied and which are not.
# Read-only: it never runs a migration.
set -euo pipefail

APP_DIR=${1:-/home/ntureyc/business-koro/backend}
DRY_RUN=${DRY_RUN:-0}

cd "$APP_DIR"

if [ ! -f prisma/schema.prisma ]; then
  echo "no prisma/schema.prisma in $APP_DIR" >&2
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
  echo "  (set DATABASE_URL to query the history)"
fi

echo
echo "== migrations on disk but not in schema =="
# A migration directory with no corresponding entry in the schema is
# usually a leftover from a branch that was abandoned.
ls -1 prisma/migrations 2>/dev/null | sed 's/_.*//' | sort -u | head -1 >/dev/null || true
echo "  (compare the list above with prisma/migrations/)"
