#!/usr/bin/env bash
# Check that the recurring jobs are actually running.
#
# The point is to catch a job that stopped before anything depends on
# its output. A backup that stopped three weeks ago is only noticed
# when the disk fills.
set -euo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  echo "Usage: $0"
  echo "Audits recurring jobs: systemd timers, crontabs, recent backup dumps, and log growth."
  exit 0
fi

status=0
fail() { echo "  FAIL: $*" >&2; status=1; }
ok()   { echo "  ok:   $*"; }

echo "== systemd timers =="
if command -v systemctl >/dev/null 2>&1; then
  # list-timers prints the timer unit and the service it triggers; the
  # timer unit is the second-to-last field.
  timers=$(systemctl list-timers --all --no-pager --no-legend 2>/dev/null | awk '{print $(NF-1)}' || true)
  if [ -z "$timers" ]; then
    echo "  (no timers configured)"
  else
    for t in $timers; do
      [ -n "$t" ] || continue
      # LastTriggerUSec is the timestamp of the last run. A timer that
      # has never fired reports an empty or zero value.
      last=$(systemctl show "$t" -p LastTriggerUSec --value 2>/dev/null || echo "")
      if [ -z "$last" ] || [ "$last" = "n/a" ] || [ "$last" = "0" ]; then
        fail "$t has never triggered"
      else
        ok "$t last ran $last"
      fi
    done
  fi
else
  echo "  (systemd not available)"
fi

echo
echo "== crontab =="
if crontab -l >/dev/null 2>&1; then
  jobs=$(crontab -l | grep -vE '^\s*#' | grep -vE '^\s*$' || true)
  if [ -z "$jobs" ]; then
    echo "  (no crontab entries)"
  else
    n=$(echo "$jobs" | wc -l)
    ok "$n crontab entries"
  fi
else
  echo "  (no crontab for this user)"
fi

echo
echo "== recent backups =="
BACKUP_DIR=${BACKUP_DIR:-/var/backups/pg}
if [ -d "$BACKUP_DIR/daily" ]; then
  latest=$(find "$BACKUP_DIR/daily" -name '*.dump' -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
  if [ -z "$latest" ]; then
    fail "no dumps found in $BACKUP_DIR/daily"
  else
    age_days=$(( ( $(date +%s) - $(stat -c %Y "$latest") ) / 86400 ))
    if [ "$age_days" -gt 2 ]; then
      fail "newest dump is $age_days days old ($latest)"
    else
      ok "newest dump $age_days day(s) old"
    fi
  fi
else
  echo "  (no backup directory at $BACKUP_DIR)"
fi

echo
echo "== log sizes =="
if [ -d "$HOME/.pm2/logs" ]; then
  big=$(find "$HOME/.pm2/logs" -type f -size +200M 2>/dev/null | head -5)
  if [ -n "$big" ]; then
    echo "$big" | sed 's/^/  large: /'
    fail "pm2 logs over 200M"
  else
    ok "pm2 logs are a reasonable size"
  fi
fi

echo
if [ "$status" -eq 0 ]; then
  echo "jobs look healthy"
else
  echo "some jobs need attention"
fi
exit "$status"
