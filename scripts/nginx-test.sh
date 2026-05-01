#!/usr/bin/env bash
# Run nginx -t and, when it fails, print the first few offending vhosts.
# A single bad file makes nginx refuse to reload, so it is worth knowing
# which file before touching anything.
set -euo pipefail

CONF_DIR=${1:-/etc/nginx/sites-enabled}

echo "== nginx -t =="
if output=$(nginx -t 2>&1); then
  echo "$output"
  echo
  echo "config is valid"
  exit 0
fi

echo "$output"
echo
echo "config is INVALID - nginx would refuse to reload."
echo

# nginx reports the offending file name; surface those so the message
# points at real files rather than only the aggregate.
bad=0

echo "Files that mention the reported error:"
err=$(echo "$output" | grep -oE '[^ ]*\.conf' | sort -u || true)
for f in $err; do
  if [ -f "$f" ]; then
    printf '  %s\n' "$f"
    bad=1
  fi
done

if [ "$bad" -eq 0 ]; then
  echo "  (could not isolate a single file - check the full output above)"
fi

exit 1
