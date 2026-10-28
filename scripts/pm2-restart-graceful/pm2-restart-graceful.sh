#!/usr/bin/env bash
# Restart pm2 apps one at a time and wait for each to come back online.
# Restarts are staggered so a crash in one app does not take down the
# whole box at once.
set -euo pipefail

DRY_RUN=${DRY_RUN:-0}
SETTLE_SECONDS=${SETTLE_SECONDS:-10}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  echo "Usage: $0 <app> [app...]"
  echo "Options/Env: DRY_RUN=1, SETTLE_SECONDS=10"
  exit 0
fi

APPS=("$@")
if [ "${#APPS[@]}" -eq 0 ]; then
  echo "usage: $0 <app> [app...]" >&2
  exit 2
fi

is_online() {
  local app=$1
  pm2 jlist 2>/dev/null | grep -q "\"name\":\"${app}\"" || return 1
  local status
  status=$(pm2 jlist | node -e '
    let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
      const p=JSON.parse(d).find(x=>x.name===process.argv[1]);
      console.log(p?p.pm2_env.status:"unknown");
    });' "$app" 2>/dev/null || echo unknown)
  [ "$status" = "online" ]
}

for app in "${APPS[@]}"; do
  echo "== $app =="

  if [ "$DRY_RUN" = "1" ]; then
    echo "  dry run, would restart $app"
    continue
  fi

  before=$(pm2 jlist | node -e '
    let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
      const p=JSON.parse(d).find(x=>x.name===process.argv[1]);
      console.log(p?p.pm2_env.restart_time:"");
    });' "$app" 2>/dev/null || echo "")

  pm2 restart "$app" >/dev/null

  # Give it a moment, then check it actually came back.
  sleep 2
  ok=0
  for _ in $(seq 1 12); do
    if is_online "$app"; then
      ok=1
      break
    fi
    sleep 1
  done

  if [ "$ok" -eq 1 ]; then
    echo "  back online"
  else
    echo "  DID NOT COME BACK - recent log:" >&2
    pm2 logs "$app" --lines 30 --nostream --err >&2 || true
    exit 1
  fi

  after=$(pm2 jlist | node -e '
    let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
      const p=JSON.parse(d).find(x=>x.name===process.argv[1]);
      console.log(p?p.pm2_env.restart_time:"");
    });' "$app" 2>/dev/null || echo "")

  if [ -n "$before" ] && [ -n "$after" ] && [ "$before" = "$after" ]; then
    echo "  warning: restart counter did not move, pm2 may have skipped it"
  fi

  if [ "$SETTLE_SECONDS" -gt 0 ]; then
    echo "  settling for ${SETTLE_SECONDS}s"
    sleep "$SETTLE_SECONDS"
  fi
done

echo
echo "all done"
