#!/usr/bin/env bash
# Show where the disk is going. Reports the biggest directories and
# the largest individual files, without needing du to be re-run twice.
set -euo pipefail

TOP=${TOP:-15}
MOUNT=${MOUNT:-/}

if [ "$(id -u)" -ne 0 ]; then
  echo "note: run as root for a complete picture" >&2
fi

echo "== filesystem =="
df -h "$MOUNT" | awk 'NR==1 || NR==2'

echo
echo "== inodes =="
df -i "$MOUNT" | awk 'NR==1 || NR==2'

echo
echo "== top directories under $MOUNT =="
du -xh --max-depth=1 "$MOUNT" 2>/dev/null | sort -rh | head -n "$((TOP + 1))" | tail -n "$TOP"

echo
echo "== largest files =="
find "$MOUNT" -xdev -type f -size +50M -printf '%10s  %p\n' 2>/dev/null \
  | sort -rn | head -n "$TOP" | awk '{ printf "%8.1f MB  %s\n", $1/1048576, $2 }'

echo
echo "== pm2 logs =="
if [ -d "$HOME/.pm2/logs" ]; then
  du -sh "$HOME/.pm2/logs" 2>/dev/null || true
  echo "  (pm2 flush empties these)"
fi

echo
echo "== postgres data directory =="
for d in /var/lib/postgresql/*/main /var/lib/postgresql/data; do
  [ -d "$d" ] && du -sh "$d" 2>/dev/null
done
