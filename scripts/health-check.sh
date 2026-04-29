#!/usr/bin/env bash
# Check that the services which should never be down are actually up.
# Prints one line per check and exits non-zero if any of them failed.
set -euo pipefail

PM2_APPS=(
  business-koro-api
  business-koro-web
  superchatbd-api
  superchatbd-web
  rananetwork-api
  rananetwork-web
  mk-manage
  hisab
  zalveriq-backend
  zalveriq-frontend
)

HTTP_CHECKS=(
  "https://api.businesskoro.com/api/v1"
  "https://superchat.bd/health"
  "https://ntureyc.xyz"
)

failed=0

echo "== pm2 =="
for app in "${PM2_APPS[@]}"; do
  if pm2 jlist 2>/dev/null | grep -q "\"name\":\"${app}\""; then
    status=$(pm2 jlist | node -e '
      let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
        const p=JSON.parse(d).find(x=>x.name===process.argv[1]);
        console.log(p?p.pm2_env.status:"unknown");
      });' "$app" 2>/dev/null || echo unknown)
    if [ "$status" = "online" ]; then
      printf '  %-24s online\n' "$app"
    else
      printf '  %-24s %s  <-- not online\n' "$app" "$status"
      failed=1
    fi
  else
    printf '  %-24s missing from pm2\n' "$app"
    failed=1
  fi
done

echo
echo "== http =="
for url in "${HTTP_CHECKS[@]}"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$url" || echo 000)
  if [ "$code" = "200" ]; then
    printf '  %-45s %s\n' "$url" "$code"
  else
    printf '  %-45s %s  <-- expected 200\n' "$url" "$code"
    failed=1
  fi
done

echo
if [ "$failed" -eq 0 ]; then
  echo "all good"
else
  echo "problems found"
fi
exit "$failed"
