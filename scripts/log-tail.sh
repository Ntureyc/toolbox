#!/usr/bin/env bash
# Pull the interesting lines out of an app log.
#
#   log-tail.sh <app> [lines]
#
# Filters out the noise that makes a real error hard to find.
set -euo pipefail

APP=${1:?usage: $0 <app> [lines]}
LINES=${2:-200}

if ! command -v pm2 >/dev/null 2>&1; then
  echo "pm2 is not installed" >&2
  exit 1
fi

log_file="$HOME/.pm2/logs/${APP}-error.log"
if [ ! -f "$log_file" ]; then
  log_file="$HOME/.pm2/logs/${APP}-out.log"
fi

if [ ! -f "$log_file" ]; then
  echo "no log file for $APP under ~/.pm2/logs" >&2
  exit 1
fi

echo "== $log_file (last $LINES lines, errors only) =="
echo

# Keep lines that look like failures and drop the stack frames and
# framework chatter around them.
grep -nEi \
  'error|exception|fatal|panic|unhandled|denied|timeout|refused|ECONN|EADDR|failed|cannot|could not|unable' \
  "$log_file" 2>/dev/null | tail -n "$LINES" || echo "  (no error lines in the tail)"

echo
echo "== last 10 lines regardless =="
tail -n 10 "$log_file"

echo
echo "== restart count =="
pm2 jlist 2>/dev/null | node -e '
  let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
    const p=JSON.parse(d).find(x=>x.name===process.argv[1]);
    if (!p) { console.log("  app not found in pm2"); return; }
    console.log("  status:", p.pm2_env.status);
    console.log("  restarts:", p.pm2_env.restart_time);
    console.log("  uptime:", p.pm2_env.pm_uptime ? Math.floor((Date.now()-p.pm2_env.pm_uptime)/1000)+"s" : "n/a");
    console.log("  memory:", Math.round((p.monit.memory||0)/1048576)+"MB");
  });' "$APP" 2>/dev/null || true
