#!/usr/bin/env bash
# Lightweight, dependency-free HTTP endpoint latency and throughput benchmarker.
#
# Usage:
#   scripts/bench-http.sh [options] <url>
#
# Options:
#   -n, --requests <N>      Total number of requests (default: 50)
#   -c, --concurrency <N>   Parallel workers (default: 5)
#   -X, --method <METHOD>   HTTP method (default: GET)
#   -H, --header <HEADER>   Custom header (e.g. -H "Authorization: Bearer token")
#   -h, --help              Show this help message
set -euo pipefail

REQUESTS=50
CONCURRENCY=5
METHOD="GET"
HEADER=""
URL=""

while [ $# -gt 0 ]; do
  case "$1" in
    -n|--requests)
      REQUESTS="$2"; shift 2 ;;
    -c|--concurrency)
      CONCURRENCY="$2"; shift 2 ;;
    -X|--method)
      METHOD="$2"; shift 2 ;;
    -H|--header)
      HEADER="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,/^set -euo pipefail/p' "$0" | grep -v '^set' | sed 's/^# //' | sed 's/^#//'
      exit 0 ;;
    *)
      URL="$1"; shift ;;
  esac
done

if [ -z "$URL" ]; then
  echo "error: url argument is required" >&2
  echo "usage: $0 [options] <url>" >&2
  exit 2
fi

bold=$(tput bold 2>/dev/null || echo "")
green=$(tput setaf 2 2>/dev/null || echo "")
yellow=$(tput setaf 3 2>/dev/null || echo "")
reset=$(tput sgr0 2>/dev/null || echo "")

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

echo "${bold}Benchmarking $URL${reset}"
echo "  Requests:    $REQUESTS"
echo "  Concurrency: $CONCURRENCY"
echo "  Method:      $METHOD"
[ -n "$HEADER" ] && echo "  Header:      $HEADER"
echo

start_time=$(date +%s%N)

# Work runner function
run_worker() {
  local count=$1
  local id=$2
  local output_file="$tmp_dir/results_${id}.txt"

  local cmd=(curl -s -o /dev/null -X "$METHOD" --max-time 10 -w '%{http_code} %{time_namelookup} %{time_connect} %{time_starttransfer} %{time_total}\n')
  [ -n "$HEADER" ] && cmd+=(-H "$HEADER")
  cmd+=("$URL")

  for ((i=1; i<=count; i++)); do
    "${cmd[@]}" >> "$output_file" 2>/dev/null || echo "000 0 0 0 0" >> "$output_file"
  done
}

# Distribute requests among concurrent workers
per_worker=$((REQUESTS / CONCURRENCY))
remainder=$((REQUESTS % CONCURRENCY))

pids=()
for ((w=1; w<=CONCURRENCY; w++)); do
  count=$per_worker
  [ "$w" -le "$remainder" ] && count=$((count + 1))
  run_worker "$count" "$w" &
  pids+=($!)
done

# Wait for all workers to complete
for pid in "${pids[@]}"; do
  wait "$pid"
done

end_time=$(date +%s%N)
total_duration_sec=$(echo "scale=4; ($end_time - $start_time) / 1000000000" | bc 2>/dev/null || awk -v s="$start_time" -v e="$end_time" 'BEGIN {printf "%.4f", (e-s)/1000000000}')

# Combine all results
combined="$tmp_dir/all.txt"
cat "$tmp_dir"/results_*.txt > "$combined"

total_sent=$(wc -l < "$combined")
success_2xx=$(grep -cE '^[23][0-9]{2}' "$combined" || true)
failed_req=$((total_sent - success_2xx))

# Parse latency numbers (in milliseconds)
times_ms="$tmp_dir/times.txt"
awk '{printf "%.2f\n", $5 * 1000}' "$combined" | sort -n > "$times_ms"

min_ms=$(head -1 "$times_ms")
max_ms=$(tail -1 "$times_ms")
avg_ms=$(awk '{sum+=$1} END {if(NR>0) printf "%.2f", sum/NR; else print "0"}' "$times_ms")

# Percentiles
get_percentile() {
  local p=$1
  local idx
  idx=$(awk -v total="$total_sent" -v p="$p" 'BEGIN { printf "%d", (total * p / 100) + 0.5 }')
  [ "$idx" -lt 1 ] && idx=1
  [ "$idx" -gt "$total_sent" ] && idx=$total_sent
  sed -n "${idx}p" "$times_ms"
}

p50=$(get_percentile 50)
p90=$(get_percentile 90)
p95=$(get_percentile 95)
p99=$(get_percentile 99)

rps=$(awk -v req="$total_sent" -v dur="$total_duration_sec" 'BEGIN {if(dur>0) printf "%.2f", req/dur; else print "0"}')

printf "\n%s=== Benchmark Results ===%s\n" "$bold" "$reset"
printf "  %-20s: %s\n" "Total Requests" "$total_sent"
printf "  %-20s: %s%s%s (2xx/3xx), %s failed\n" "Status Codes" "$green" "$success_2xx" "$reset" "$failed_req"
printf "  %-20s: %ss\n" "Total Time" "$total_duration_sec"
printf "  %-20s: %s%s req/sec%s\n" "Throughput" "$bold$green" "$rps" "$reset"

printf "\n%s=== Latency Distribution (ms) ===%s\n" "$bold" "$reset"
printf "  %-12s: %8s ms\n" "Min" "$min_ms"
printf "  %-12s: %8s ms\n" "Avg" "$avg_ms"
printf "  %-12s: %8s ms\n" "p50 (Median)" "$p50"
printf "  %-12s: %8s ms\n" "p90" "$p90"
printf "  %-12s: %8s ms\n" "p95" "$p95"
printf "  %-12s: %8s ms\n" "p99" "$p99"
printf "  %-12s: %8s ms\n" "Max" "$max_ms"
echo
