#!/usr/bin/env bash
# Pre-restart checks for a deploy.
#
#   scripts/deploy-check.sh <app-dir> [expected-commit]
#
# Verifies the things that are cheap to check and expensive to discover
# after a restart: the build exists, the lockfile is in sync, and the
# process is not already crash-looping.
set -euo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ $# -eq 0 ]; then
  sed -n '2,/^set -euo pipefail/p' "$0" | grep -v '^set' | sed 's/^# //' | sed 's/^#//'
  exit 0
fi

APP_DIR=${1}
EXPECTED=${2:-}

cd "$APP_DIR"

status=0
fail() { echo "  FAIL: $*" >&2; status=1; }
ok()   { echo "  ok:   $*"; }

echo "== $APP_DIR =="

# The build output has to exist, otherwise pm2 starts a process that
# exits immediately.
ENTRY="${BUILD_ENTRY:-}"
if [ -n "$ENTRY" ] && [ -e "$ENTRY" ]; then
  ok "build entrypoint ($ENTRY) present"
elif [ -f dist/main.js ] || [ -f dist/index.js ] || [ -f build/index.js ] || [ -f build/main.js ] || [ -f .next/BUILD_ID ]; then
  found=$(ls -1 dist/main.js dist/index.js build/index.js build/main.js .next/BUILD_ID 2>/dev/null | head -1)
  ok "build output ($found) present"
elif [ -f package.json ] && ! grep -q '"build"' package.json; then
  ok "no build step defined in package.json"
else
  fail "build output missing (checked dist/, build/, .next/) - set BUILD_ENTRY or run build first"
fi

# Lockfile drift means the deployed tree is not the tested tree.
if [ -f bun.lockb ] || [ -f bun.lock ]; then
  if command -v bun >/dev/null 2>&1; then
    if bun install --frozen-lockfile --dry-run >/dev/null 2>&1; then
      ok "lockfile in sync"
    else
      fail "lockfile out of sync - run 'bun install' and commit the result"
    fi
  fi
elif [ -f package-lock.json ]; then
  if npm ci --dry-run >/dev/null 2>&1; then
    ok "package-lock in sync"
  else
    fail "package-lock out of sync"
  fi
fi

# A process that is already restarting is not going to be helped by
# restarting it again.
if command -v pm2 >/dev/null 2>&1; then
  app=$(basename "$APP_DIR")
  if pm2 jlist 2>/dev/null | grep -q "\"name\":\"${app}\""; then
    restarts=$(pm2 jlist | node -e '
      let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
        const p=JSON.parse(d).find(x=>x.name===process.argv[1]);
        console.log(p&&p.pm2_env?p.pm2_env.restart_time:0);
      });' "$app" 2>/dev/null || echo 0)
    if [ "${restarts:-0}" -gt 0 ]; then
      echo "  note: $app has restarted $restarts time(s) already"
    fi
  fi
fi

# If the caller told us which commit should be deployed, check it.
if [ -n "$EXPECTED" ]; then
  actual=$(git rev-parse --short HEAD)
  if [ "$actual" = "${EXPECTED:0:7}" ]; then
    ok "HEAD is $actual"
  else
    fail "HEAD is $actual, expected $EXPECTED"
  fi
  if ! git diff --quiet || ! git diff --cached --quiet; then
    fail "working tree is dirty - uncommitted changes will not be deployed"
  else
    ok "working tree clean"
  fi
fi

if [ "$status" -eq 0 ]; then
  echo "  ready to restart"
else
  echo "  NOT ready"
fi
exit "$status"
