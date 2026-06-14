#!/usr/bin/env bash
# Verify a Next.js build before it is restarted in production.
#
#   next-build-check.sh <app-dir>
#
# Catches the two failures that are invisible until a user opens the
# page: missing static assets in a standalone build, and a public
# variable that was empty at build time.
set -euo pipefail

APP_DIR=${1:?usage: $0 <app-dir>}
cd "$APP_DIR"

status=0
fail() { echo "  FAIL: $*" >&2; status=1; }
ok()   { echo "  ok:   $*"; }

echo "== $APP_DIR =="

if [ ! -d .next ]; then
  fail ".next does not exist - the build did not run"
  exit 1
fi
ok ".next present"

# Standalone output needs the static directory copied in. Without it the
# app serves HTML that references assets that 404.
if [ -d dist/standalone ]; then
  if [ -d dist/standalone/.next/static ]; then
    ok "standalone build has .next/static"
  else
    fail "standalone build is missing .next/static - copy it before deploying"
  fi

  if [ -d public ] && [ ! -d dist/standalone/public ]; then
    fail "standalone build is missing public/ - copy it before deploying"
  else
    ok "public/ present in standalone build"
  fi

  if [ -f dist/standalone/server.js ]; then
    ok "server.js present"
  else
    fail "server.js missing from the standalone build"
  fi
fi

# NEXT_PUBLIC_ variables are inlined at build time, so an empty value
# in the bundle is a build-time mistake that a restart cannot fix.
public_vars=$(grep -rhoE 'NEXT_PUBLIC_[A-Z0-9_]+' .next 2>/dev/null | sort -u || true)
if [ -n "$public_vars" ]; then
  echo "  public variables referenced:"
  for v in $public_vars; do
    q='"'
    pattern="${q}${v}${q}:${q}[^${q}]*${q}"
    val=$(grep -rhoE "$pattern" .next 2>/dev/null | head -1 | sed "s/.*:${q}//; s/${q}\$//" || true)
    if [ -z "$val" ] || [ "$val" = "undefined" ]; then
      fail "$v was empty or undefined at build time"
    else
      ok "$v = $val"
    fi
  done
fi

# A build that produced an error page is still a build that exits 0.
if [ -f .next/BUILD_ID ]; then
  ok "BUILD_ID $(cat .next/BUILD_ID)"
else
  fail "no BUILD_ID - the build did not complete"
fi

if [ "$status" -eq 0 ]; then
  echo "  build looks deployable"
else
  echo "  DO NOT DEPLOY"
fi
exit "$status"
