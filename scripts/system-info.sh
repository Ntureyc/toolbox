#!/usr/bin/env bash
# Quick, visual server snapshot and hardware/OS diagnostic overview.
#
# Usage:
#   scripts/system-info.sh
set -euo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,/^set -euo pipefail/p' "$0" | grep -v '^set' | sed 's/^# //' | sed 's/^#//'
  exit 0
fi

bold=$(tput bold 2>/dev/null || echo "")
reset=$(tput sgr0 2>/dev/null || echo "")
dim=$(tput dim 2>/dev/null || echo "")

print_header() {
  printf "\n%s=== %s ===%s\n" "$bold" "$1" "$reset"
}

# 1. System & OS
print_header "System & OS"
hostname_str=$(hostname 2>/dev/null || uname -n)
os_desc="Linux"
if [ -f /etc/os-release ]; then
  os_desc=$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"')
fi
kernel=$(uname -r)
uptime_str=$(uptime -p 2>/dev/null || uptime | sed 's/.*up \([^,]*\), .*/\1/')

printf "  %-18s: %s\n" "Hostname" "$hostname_str"
printf "  %-18s: %s\n" "OS" "$os_desc"
printf "  %-18s: %s\n" "Kernel" "$kernel"
printf "  %-18s: %s\n" "Uptime" "$uptime_str"

# 2. CPU & Load
print_header "CPU & Load"
cpu_model=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^[ \t]*//' || echo "Unknown CPU")
cpu_cores=$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo "1")
load_avg=$(cat /proc/loadavg 2>/dev/null | awk '{printf "%s (1m), %s (5m), %s (15m)", $1, $2, $3}' || echo "N/A")

printf "  %-18s: %s (%s cores)\n" "CPU Model" "$cpu_model" "$cpu_cores"
printf "  %-18s: %s\n" "Load Average" "$load_avg"

# 3. Memory & Swap
print_header "Memory & Swap"
if command -v free >/dev/null 2>&1; then
  free -h | awk '
    NR==1 { printf "  %-10s %10s %10s %10s %10s\n", "Type", "Total", "Used", "Free", "Available" }
    NR==2 { printf "  %-10s %10s %10s %10s %10s\n", "RAM", $2, $3, $4, $7 }
    NR==3 { printf "  %-10s %10s %10s %10s\n", "Swap", $2, $3, $4 }
  '
fi

# 4. Storage
print_header "Storage (Filesystems)"
df -h -x tmpfs -x devtmpfs -x overlay 2>/dev/null | awk '
  NR==1 { printf "  %-24s %8s %8s %8s %6s %s\n", "Filesystem", "Size", "Used", "Avail", "Use%", "Mounted on" }
  NR>1  { printf "  %-24s %8s %8s %8s %6s %s\n", substr($1,1,24), $2, $3, $4, $5, $6 }
'

# 5. Network & Public IP
print_header "Network"
default_iface=$(ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -1 || echo "")
if [ -n "$default_iface" ]; then
  local_ip=$(ip -4 addr show dev "$default_iface" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -1 || echo "unknown")
  printf "  %-18s: %s (%s)\n" "Primary Interface" "$default_iface" "$local_ip"
fi

# Fetch public IP with short timeout
public_ip=$(curl -s --max-time 2 https://api.ipify.org 2>/dev/null || echo "could not detect")
printf "  %-18s: %s\n" "Public IPv4" "$public_ip"

# 6. Key Services
print_header "Active Key Services"
check_service() {
  local name=$1
  if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet "$name" 2>/dev/null; then
    printf "  %-18s: %srunning (systemd)%s\n" "$name" "$bold" "$reset"
  elif pgrep -f "$name" >/dev/null 2>&1; then
    printf "  %-18s: %srunning (process)%s\n" "$name" "$bold" "$reset"
  else
    printf "  %-18s: %snot running / inactive%s\n" "$name" "$dim" "$reset"
  fi
}

for s in nginx docker postgresql redis-server pm2; do
  check_service "$s"
done

echo
