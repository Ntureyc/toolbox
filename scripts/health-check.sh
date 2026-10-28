#!/usr/bin/env bash
# Flexible, one-shot health checker for applications and system resources.
#
# Usage:
#   scripts/health-check.sh [options]
#
# Options:
#   -a, --apps "app1 app2"   PM2 application names to check (defaults to all registered PM2 apps)
#   -u, --urls "url1 url2"   HTTP/HTTPS endpoints to verify (expecting 200/2xx)
#   -s, --system             Include system metrics check (disk, memory, load)
#   -h, --help               Show this help message
#
# Environment variables:
#   CHECK_APPS               Space/comma-separated app names
#   CHECK_URLS               Space/comma-separated URLs to probe
#   CHECK_SYSTEM             Set to 1 to enable system threshold checks (default: 1)
#   HTTP_TIMEOUT             curl max-time per request in seconds (default: 5)
set -euo pipefail

APPS_ARG="${CHECK_APPS:-}"
URLS_ARG="${CHECK_URLS:-}"
CHECK_SYS="${CHECK_SYSTEM:-1}"
HTTP_TIMEOUT="${HTTP_TIMEOUT:-5}"

while [ $# -gt 0 ]; do
  case "$1" in
    -a|--apps)
      APPS_ARG="$2"; shift 2 ;;
    -u|--urls)
      URLS_ARG="$2"; shift 2 ;;
    -s|--system)
      CHECK_SYS=1; shift ;;
    --no-system)
      CHECK_SYS=0; shift ;;
    -h|--help)
      sed -n '2,/^set -euo pipefail/p' "$0" | grep -v '^set' | sed 's/^# //' | sed 's/^#//'
      exit 0 ;;
    *)
      APPS_ARG="${APPS_ARG} $1"; shift ;;
  esac
done

failed=0

# Normalize comma-separated to space-separated
APPS_ARG=$(echo "$APPS_ARG" | tr ',' ' ')
URLS_ARG=$(echo "$URLS_ARG" | tr ',' ' ')

# 1. System Metrics Check
if [ "$CHECK_SYS" = "1" ]; then
  echo "== system =="
  # Disk check on root mount
  if command -v df >/dev/null 2>&1; then
    disk_use=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    disk_avail=$(df -h / | awk 'NR==2 {print $4}')
    if [ "${disk_use:-0}" -ge 95 ]; then
      printf '  %-24s %s%% used (avail: %s)  <-- CRITICAL DISK\n' "disk (/)" "$disk_use" "$disk_avail"
      failed=1
    elif [ "${disk_use:-0}" -ge 85 ]; then
      printf '  %-24s %s%% used (avail: %s)  <-- WARN (high)\n' "disk (/)" "$disk_use" "$disk_avail"
    else
      printf '  %-24s %s%% used (avail: %s)  [ok]\n' "disk (/)" "$disk_use" "$disk_avail"
    fi
  fi

  # Memory check
  if command -v free >/dev/null 2>&1; then
    mem_total=$(free -m | awk '/^Mem:/ {print $2}')
    mem_avail=$(free -m | awk '/^Mem:/ {print $7}')
    if [ -n "$mem_total" ] && [ -n "$mem_avail" ] && [ "$mem_total" -gt 0 ]; then
      mem_used_pct=$(( (mem_total - mem_avail) * 100 / mem_total ))
      if [ "$mem_used_pct" -ge 95 ]; then
        printf '  %-24s %s%% used (%sM avail)  <-- CRITICAL MEMORY\n' "memory" "$mem_used_pct" "$mem_avail"
        failed=1
      elif [ "$mem_used_pct" -ge 90 ]; then
        printf '  %-24s %s%% used (%sM avail)  <-- WARN\n' "memory" "$mem_used_pct" "$mem_avail"
      else
        printf '  %-24s %s%% used (%sM avail)  [ok]\n' "memory" "$mem_used_pct" "$mem_avail"
      fi
    fi
  fi

  # Load average
  if [ -r /proc/loadavg ]; then
    load1=$(awk '{print $1}' /proc/loadavg)
    cores=$(nproc 2>/dev/null || echo 1)
    printf '  %-24s 1m: %s (cores: %s)  [ok]\n' "load average" "$load1" "$cores"
  fi
  echo
fi

# 2. PM2 Process Check
echo "== pm2 =="
if command -v pm2 >/dev/null 2>&1; then
  pm2_json=$(pm2 jlist 2>/dev/null || echo "[]")
  
  # Determine target apps list
  declare -a APPS_TO_CHECK=()
  if [ -n "$APPS_ARG" ]; then
    for app in $APPS_ARG; do
      APPS_TO_CHECK+=("$app")
    done
  else
    # Auto-detect all apps registered in PM2
    mapfile -t detected < <(echo "$pm2_json" | node -e '
      let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
        try {
          const list=JSON.parse(d);
          const names=[...new Set(list.map(p=>p.name))];
          names.forEach(n => console.log(n));
        } catch(e) {}
      });' 2>/dev/null || true)
    for app in "${detected[@]}"; do
      [ -n "$app" ] && APPS_TO_CHECK+=("$app")
    done
  fi

  if [ "${#APPS_TO_CHECK[@]}" -eq 0 ]; then
    echo "  (no PM2 apps found or configured)"
  else
    for app in "${APPS_TO_CHECK[@]}"; do
      app_status=$(echo "$pm2_json" | node -e '
        let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
          try {
            const list=JSON.parse(d);
            const found=list.filter(x=>x.name===process.argv[1]);
            if (!found.length) { console.log("missing"); return; }
            const allOnline = found.every(p=>p.pm2_env&&p.pm2_env.status==="online");
            console.log(allOnline ? "online" : found.map(p=>p.pm2_env.status).join(","));
          } catch(e) { console.log("unknown"); }
        });' "$app" 2>/dev/null || echo "unknown")

      if [ "$app_status" = "online" ]; then
        printf '  %-24s %s\n' "$app" "$app_status"
      else
        printf '  %-24s %s  <-- not online\n' "$app" "$app_status"
        failed=1
      fi
    done
  fi
else
  echo "  (pm2 is not installed or not in PATH)"
fi

# 3. HTTP Endpoints Check
if [ -n "$URLS_ARG" ]; then
  echo
  echo "== http =="
  for url in $URLS_ARG; do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time "$HTTP_TIMEOUT" "$url" 2>/dev/null || echo "000")
    if [[ "$code" =~ ^2[0-9]{2}$ ]]; then
      printf '  %-45s %s  [ok]\n' "$url" "$code"
    elif [[ "$code" =~ ^3[0-9]{2}$ ]]; then
      printf '  %-45s %s  [redirect]\n' "$url" "$code"
    else
      printf '  %-45s %s  <-- unexpected response\n' "$url" "$code"
      failed=1
    fi
  done
fi

echo
if [ "$failed" -eq 0 ]; then
  echo "all good"
else
  echo "problems found"
fi
exit "$failed"
