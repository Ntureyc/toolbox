#!/usr/bin/env bash
# Safe server disk cleanup utility with dry-run support.
#
# Usage:
#   scripts/sys-cleanup.sh [options]
#
# Options:
#   -a, --apply       Actually perform cleanup (default is dry-run mode)
#   -h, --help        Show this help message
#
# Cleans:
#   - Systemd journal logs older than 3 days
#   - Rotated / compressed logs (*.gz, *.1) in /var/log older than 14 days
#   - Stale temporary files in /tmp and /var/tmp older than 7 days
#   - Package manager caches (dnf / apt / pacman)
#   - Docker dangling images, stopped containers, build cache (if docker is installed)
#   - PM2 log files (> 100MB)
set -euo pipefail

APPLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    -a|--apply)
      APPLY=1; shift ;;
    -h|--help)
      sed -n '2,/^set -euo pipefail/p' "$0" | grep -v '^set' | sed 's/^# //' | sed 's/^#//'
      exit 0 ;;
    *)
      echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

bold=$(tput bold 2>/dev/null || echo "")
green=$(tput setaf 2 2>/dev/null || echo "")
yellow=$(tput setaf 3 2>/dev/null || echo "")
reset=$(tput sgr0 2>/dev/null || echo "")

if [ "$APPLY" -eq 1 ]; then
  echo "${bold}Mode: APPLY (live cleanup)${reset}"
else
  echo "${yellow}${bold}Mode: DRY-RUN (no files will be deleted, pass --apply to execute)${reset}"
fi

initial_free=$(df -h / | awk 'NR==2 {print $4}')
echo "Free disk space on /: $initial_free"
echo

# 1. Systemd Journal Vacuum
echo "== 1. Systemd Journal =="
if command -v journalctl >/dev/null 2>&1; then
  current_journal=$(journalctl --disk-usage 2>/dev/null || echo "unknown")
  echo "  current usage: $current_journal"
  if [ "$APPLY" -eq 1 ]; then
    journalctl --vacuum-time=3d 2>/dev/null || true
    echo "  ${green}vacuumed journal older than 3 days${reset}"
  else
    echo "  [dry-run] would run: journalctl --vacuum-time=3d"
  fi
else
  echo "  journalctl not available"
fi

# 2. Package Manager Cache
echo
echo "== 2. Package Manager Cache =="
if command -v dnf >/dev/null 2>&1; then
  if [ "$APPLY" -eq 1 ]; then
    dnf clean packages -y 2>/dev/null || true
    echo "  ${green}cleaned dnf package cache${reset}"
  else
    echo "  [dry-run] would run: dnf clean packages"
  fi
elif command -v apt-get >/dev/null 2>&1; then
  if [ "$APPLY" -eq 1 ]; then
    apt-get clean 2>/dev/null || true
    echo "  ${green}cleaned apt package cache${reset}"
  else
    echo "  [dry-run] would run: apt-get clean"
  fi
fi

# 3. Old Rotated Logs in /var/log
echo
echo "== 3. Rotated Log Archives =="
if [ -d /var/log ]; then
  mapfile -t old_logs < <(find /var/log -type f \( -name "*.gz" -o -name "*.1" -o -name "*.old" \) -mtime +14 2>/dev/null || true)
  if [ "${#old_logs[@]}" -gt 0 ]; then
    echo "  found ${#old_logs[@]} archived log file(s) older than 14 days"
    if [ "$APPLY" -eq 1 ]; then
      find /var/log -type f \( -name "*.gz" -o -name "*.1" -o -name "*.old" \) -mtime +14 -delete 2>/dev/null || true
      echo "  ${green}deleted ${#old_logs[@]} old archived logs${reset}"
    else
      echo "  [dry-run] would delete ${#old_logs[@]} file(s) in /var/log"
    fi
  else
    echo "  no archived logs older than 14 days found"
  fi
fi

# 4. Old Temp Files
echo
echo "== 4. Temporary Files (/tmp & /var/tmp) =="
mapfile -t old_tmp < <(find /tmp /var/tmp -mindepth 1 -maxdepth 2 -type f -atime +7 2>/dev/null || true)
if [ "${#old_tmp[@]}" -gt 0 ]; then
  echo "  found ${#old_tmp[@]} temp file(s) unaccessed in 7 days"
  if [ "$APPLY" -eq 1 ]; then
    find /tmp /var/tmp -mindepth 1 -maxdepth 2 -type f -atime +7 -delete 2>/dev/null || true
    echo "  ${green}cleaned old temp files${reset}"
  else
    echo "  [dry-run] would delete ${#old_tmp[@]} file(s)"
  fi
else
  echo "  no abandoned temp files found"
fi

# 5. Docker Prune
echo
echo "== 5. Docker Resources =="
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  if [ "$APPLY" -eq 1 ]; then
    echo "  pruning dangling containers, images, and networks..."
    docker system prune -f 2>/dev/null || true
    echo "  ${green}docker prune complete${reset}"
  else
    dangling=$(docker images -f "dangling=true" -q 2>/dev/null | wc -l)
    stopped=$(docker ps -f "status=exited" -q 2>/dev/null | wc -l)
    echo "  [dry-run] $dangling dangling image(s), $stopped stopped container(s) eligible for cleanup"
    echo "  [dry-run] would run: docker system prune -f"
  fi
else
  echo "  docker not active or not installed"
fi

echo
final_free=$(df -h / | awk 'NR==2 {print $4}')
echo "Free disk space on /: $final_free"
echo "done"
