#!/usr/bin/env bash
# Pull the interesting error lines out of an app or system log.
#
# Usage:
#   scripts/log-tail.sh <app-name-or-file> [lines]
#
# Filters out the noise and highlights actual errors, exceptions, and timeouts.
set -euo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ $# -eq 0 ]; then
  sed -n '2,/^set -euo pipefail/p' "$0" | grep -v '^set' | sed 's/^# //' | sed 's/^#//'
  exit 0
fi

TARGET="$1"
LINES="${2:-200}"

log_file=""

if [ -f "$TARGET" ]; then
  log_file="$TARGET"
elif [ -d "$HOME/.pm2/logs" ]; then
  if [ -f "$HOME/.pm2/logs/${TARGET}-error.log" ]; then
    log_file="$HOME/.pm2/logs/${TARGET}-error.log"
  elif [ -f "$HOME/.pm2/logs/${TARGET}-out.log" ]; then
    log_file="$HOME/.pm2/logs/${TARGET}-out.log"
  fi
fi

if [ -z "$log_file" ] && command -v pm2 >/dev/null 2>&1; then
  # Try to extract log path directly from PM2
  custom_path=$(pm2 describe "$TARGET" 2>/dev/null | awk '/error log path/ {print $NF}' || true)
  if [ -n "$custom_path" ] && [ -f "$custom_path" ]; then
    log_file="$custom_path"
  fi
fi

if [ -z "$log_file" ] || [ ! -f "$log_file" ]; then
  echo "error: could not locate log file for '$TARGET'" >&2
  echo "looked in: ~/.pm2/logs/${TARGET}-error.log and direct path" >&2
  exit 1
fi

echo "== $log_file (last $LINES lines, filtered for errors) =="
echo

# Keep lines that look like failures and drop surrounding chatter
grep -nEi \
  'error|exception|fatal|panic|unhandled|denied|timeout|refused|ECONN|EADDR|failed|cannot|could not|unable' \
  "$log_file" 2>/dev/null | tail -n "$LINES" || echo "  (no error lines in the tail)"

echo
echo "== last 10 lines unfiltered =="
tail -n 10 "$log_file"

if command -v pm2 >/dev/null 2>&1 && pm2 jlist 2>/dev/null | grep -q "\"name\":\"${TARGET}\""; then
  echo
  echo "== pm2 status =="
  pm2 jlist 2>/dev/null | node -e '
    let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
      try {
        const p=JSON.parse(d).find(x=>x.name===process.argv[1]);
        if (!p) return;
        console.log("  status:  ", p.pm2_env.status);
        console.log("  restarts:", p.pm2_env.restart_time);
        console.log("  uptime:  ", p.pm2_env.pm_uptime ? Math.floor((Date.now()-p.pm2_env.pm_uptime)/1000)+"s" : "n/a");
        console.log("  memory:  ", Math.round((p.monit.memory||0)/1048576)+"MB");
      } catch(e) {}
    });' "$TARGET" 2>/dev/null || true
fi
