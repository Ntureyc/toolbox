#!/usr/bin/env bash
# Logical Postgres backups with tiered retention.
#
#   daily   - 14 days
#   weekly  - 8 weeks
#   monthly - 12 months
#
# Each tier is a separate directory; a dump is hard-linked into the
# weekly and monthly tiers so the three copies cost one file.
set -euo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  echo "Usage: DATABASE_URL=<url> $0"
  echo "   or: $0 <database-url>"
  echo "Options/Env: BACKUP_DIR=/var/backups/pg, DRY_RUN=1, KEEP_DAILY=14, KEEP_WEEKLY=8, KEEP_MONTHLY=12"
  exit 0
fi

BACKUP_DIR=${BACKUP_DIR:-/var/backups/pg}
DATABASE_URL=${1:-${DATABASE_URL:-}}
if [ -z "$DATABASE_URL" ]; then
  echo "error: DATABASE_URL must be set as an environment variable or passed as argument 1" >&2
  exit 2
fi
KEEP_DAILY=${KEEP_DAILY:-14}
KEEP_WEEKLY=${KEEP_WEEKLY:-8}
KEEP_MONTHLY=${KEEP_MONTHLY:-12}

DRY_RUN=${DRY_RUN:-0}

mkdir -p "$BACKUP_DIR"/{daily,weekly,monthly}

today=$(date +%F)
name=$(basename "${DATABASE_URL%%\?*}" | tr -c 'a-zA-Z0-9_-' '_')
target="$BACKUP_DIR/daily/${name}_${today}.dump"

log() { printf '%s %s\n' "$(date -Is)" "$*"; }

if [ "$DRY_RUN" = "1" ]; then
  log "dry run: would dump $DATABASE_URL -> $target"
  exit 0
fi

log "dumping $name"
if ! pg_dump --format=custom --compress=9 --file="$target" "$DATABASE_URL"; then
  log "pg_dump failed for $name"
  exit 1
fi

size=$(du -h "$target" | cut -f1)
log "wrote $target ($size)"

# Weekly: the same file, hard-linked, named by the ISO week.
week=$(date +%G-W%V)
ln -f "$target" "$BACKUP_DIR/weekly/${name}_${week}.dump"

# Monthly: same file again, named by year-month.
month=$(date +%Y-%m)
ln -f "$target" "$BACKUP_DIR/monthly/${name}_${month}.dump"

# Prune. Find files older than the window in each tier.
prune() {
  local dir=$1 keep=$2
  [ -d "$dir" ] || return 0
  find "$dir" -maxdepth 1 -name "${name}_*.dump" -type f -mtime "+$keep" -print -delete 2>/dev/null || true
}

prune "$BACKUP_DIR/daily" "$KEEP_DAILY"
prune "$BACKUP_DIR/weekly" "$((KEEP_WEEKLY * 7))"
prune "$BACKUP_DIR/monthly" "$((KEEP_MONTHLY * 30))"

total=$(du -sh "$BACKUP_DIR" | cut -f1)
log "retention applied, ${BACKUP_DIR} now $total"
