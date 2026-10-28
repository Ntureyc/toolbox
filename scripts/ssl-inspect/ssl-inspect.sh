#!/usr/bin/env bash
# Inspect remote SSL/TLS certificates and connection parameters without a browser.
#
# Usage:
#   scripts/ssl-inspect.sh <host> [port]
#   scripts/ssl-inspect.sh github.com
#   scripts/ssl-inspect.sh api.example.com 8443
set -euo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ $# -eq 0 ]; then
  sed -n '2,/^set -euo pipefail/p' "$0" | grep -v '^set' | sed 's/^# //' | sed 's/^#//'
  exit 0
fi

TARGET="$1"
PORT="${2:-443}"

# If user passed host:port as single arg, split it
if [[ "$TARGET" =~ :[0-9]+$ ]]; then
  PORT="${TARGET##*:}"
  TARGET="${TARGET%:*}"
fi

# Strip https:// or http:// if user pasted a full URL
TARGET=$(echo "$TARGET" | sed -e 's|^https://||' -e 's|^http://||' -e 's|/.*$||')

bold=$(tput bold 2>/dev/null || echo "")
red=$(tput setaf 1 2>/dev/null || echo "")
green=$(tput setaf 2 2>/dev/null || echo "")
yellow=$(tput setaf 3 2>/dev/null || echo "")
reset=$(tput sgr0 2>/dev/null || echo "")

echo "Connecting to $TARGET:$PORT..."

# Fetch certificate and connection details
raw_out=$(echo "" | openssl s_client -connect "${TARGET}:${PORT}" -servername "${TARGET}" -showcerts -status 2>&1 || true)

if ! echo "$raw_out" | grep -q "BEGIN CERTIFICATE"; then
  echo "error: failed to retrieve SSL/TLS certificate from $TARGET:$PORT" >&2
  echo "$raw_out" | head -n 10 >&2
  exit 1
fi

cert_pem=$(echo "$raw_out" | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' | head -n 35)

# Extract fields
subject=$(echo "$cert_pem" | openssl x509 -noout -subject 2>/dev/null | sed 's/^subject= *//')
issuer=$(echo "$cert_pem" | openssl x509 -noout -issuer 2>/dev/null | sed 's/^issuer= *//')
dates=$(echo "$cert_pem" | openssl x509 -noout -dates 2>/dev/null)
not_before=$(echo "$dates" | awk -F= '/notBefore/ {print $2}')
not_after=$(echo "$dates" | awk -F= '/notAfter/ {print $2}')
san=$(echo "$cert_pem" | openssl x509 -noout -ext subjectAltName 2>/dev/null | sed -e '1d' -e 's/^[ \t]*//' || echo "")
serial=$(echo "$cert_pem" | openssl x509 -noout -serial 2>/dev/null | cut -d= -f2)

# Calculate days remaining
now_epoch=$(date +%s)
end_epoch=$(date -d "$not_after" +%s 2>/dev/null || echo 0)
days_left=$(( (end_epoch - now_epoch) / 86400 ))

# Extract TLS handshake info
tls_ver=$(echo "$raw_out" | grep -m1 -i "Protocol" | sed 's/.*Protocol[ :]*//' | awk '{print $1}' || echo "unknown")
cipher=$(echo "$raw_out" | grep -m1 -i "Cipher is" | sed 's/.*Cipher is //' | awk '{print $1}' || true)
if [ -z "$cipher" ]; then
  cipher=$(echo "$raw_out" | grep -m1 -i "Cipher[ :]" | awk -F: '{print $NF}' | tr -d ' ' || echo "unknown")
fi
alpn=$(echo "$raw_out" | grep -m1 "ALPN protocol:" | awk -F: '{print $NF}' | tr -d ' ' || echo "none negotiated")
ocsp=$(echo "$raw_out" | grep -A 5 "OCSP Response Data:" | grep "OCSP Response Status:" | head -1 | awk '{print $NF}' || echo "not stapled")

printf "\n%s=== Certificate Details ===%s\n" "$bold" "$reset"
printf "  %-18s: %s\n" "Common Name" "$subject"
printf "  %-18s: %s\n" "Issuer" "$issuer"
printf "  %-18s: %s\n" "Serial" "$serial"
printf "  %-18s: %s\n" "Valid From" "$not_before"
printf "  %-18s: %s\n" "Valid Until" "$not_after"

# Colorize days remaining
if [ "$days_left" -lt 7 ]; then
  printf "  %-18s: %b%s days (CRITICAL: RENEW NOW)%b\n" "Days Remaining" "$red$bold" "$days_left" "$reset"
elif [ "$days_left" -lt 30 ]; then
  printf "  %-18s: %b%s days (Expiring soon)%b\n" "Days Remaining" "$yellow" "$days_left" "$reset"
else
  printf "  %-18s: %b%s days%b\n" "Days Remaining" "$green" "$days_left" "$reset"
fi

if [ -n "$san" ]; then
  printf "  %-18s: %s\n" "SANs" "$san"
fi

printf "\n%s=== Connection & Protocol ===%s\n" "$bold" "$reset"
printf "  %-18s: %s\n" "Protocol" "$tls_ver"
printf "  %-18s: %s\n" "Cipher" "$cipher"
printf "  %-18s: %s\n" "ALPN" "$alpn"
printf "  %-18s: %s\n" "OCSP Stapling" "$ocsp"
echo
