#!/usr/bin/env bash
# Audit listening ports and identify publicly exposed services vs local bindings.
#
# Usage:
#   scripts/port-audit.sh [options]
#
# Options:
#   -w, --warn-only   Only show sensitive services bound to public interfaces (0.0.0.0 / ::)
#   -h, --help        Show this help message
set -euo pipefail

WARN_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    -w|--warn-only)
      WARN_ONLY=1; shift ;;
    -h|--help)
      sed -n '2,/^set -euo pipefail/p' "$0" | grep -v '^set' | sed 's/^# //' | sed 's/^#//'
      exit 0 ;;
    *)
      echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  echo "note: run as root (or with sudo) to see process names and PIDs for all sockets" >&2
fi

bold=$(tput bold 2>/dev/null || echo "")
red=$(tput setaf 1 2>/dev/null || echo "")
green=$(tput setaf 2 2>/dev/null || echo "")
yellow=$(tput setaf 3 2>/dev/null || echo "")
reset=$(tput sgr0 2>/dev/null || echo "")

# List of ports typically intended to stay internal
INTERNAL_PORTS="5432 3306 6379 27017 9200 11211 2375 2376 9090 9100 8086"

is_sensitive_port() {
  local p="$1"
  for s in $INTERNAL_PORTS; do
    if [ "$p" = "$s" ]; then return 0; fi
  done
  return 1
}

printf "\n%s%-6s %-6s %-22s %-8s %-20s %-15s%s\n" "$bold" "PROTO" "PORT" "LOCAL ADDRESS" "PID" "PROCESS" "EXPOSURE" "$reset"
printf "%-6s %-6s %-22s %-8s %-20s %-15s\n" "-----" "----" "-------------" "---" "-------" "--------"

# Use ss if available, fallback to netstat
if command -v ss >/dev/null 2>&1; then
  # ss output columns: Netid, State, Recv-Q, Send-Q, Local Address:Port, Peer Address:Port, Process
  ss -tulnpH 2>/dev/null | sort -k1,1 -k5,5 | while read -r line; do
    [ -n "$line" ] || continue
    proto=$(echo "$line" | awk '{print $1}')
    local_addr=$(echo "$line" | awk '{print $5}')
    proc_info=$(echo "$line" | awk '{for(i=7;i<=NF;++i) printf "%s ", $i}')

    # Extract port
    port="${local_addr##*:}"
    host="${local_addr%:*}"

    # Extract PID and process name
    proc_name="-"
    pid="-"
    if [[ "$proc_info" =~ users:\(\(\"([^\"]+)\",pid=([0-9]+) ]]; then
      proc_name="${BASH_REMATCH[1]}"
      pid="${BASH_REMATCH[2]}"
    elif [[ "$proc_info" =~ users:\(\(\"([^\"]+)\" ]]; then
      proc_name="${BASH_REMATCH[1]}"
    fi

    # Classify exposure
    status="LOCAL"
    color="$green"
    if [ "$host" = "*" ] || [ "$host" = "0.0.0.0" ] || [ "$host" = "::" ] || [ "$host" = "[::]" ]; then
      if is_sensitive_port "$port"; then
        status="EXPOSED [!]"
        color="$red$bold"
      else
        status="PUBLIC"
        color="$yellow"
      fi
    fi

    if [ "$WARN_ONLY" = "1" ] && [ "$status" != "EXPOSED [!]" ]; then
      continue
    fi

    printf "%-6s %-6s %-22s %-8s %-20s %b%-15s%b\n" \
      "$proto" "$port" "$local_addr" "$pid" "$proc_name" "$color" "$status" "$reset"
  done
else
  echo "ss is not available" >&2
  exit 1
fi

echo
