#!/usr/bin/env bash
# Audit and validate .env files against .env.example templates.
#
# Usage:
#   scripts/env-audit.sh [env-file] [example-file]
#
# Defaults:
#   env-file:     .env
#   example-file: .env.example
set -euo pipefail

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,/^set -euo pipefail/p' "$0" | grep -v '^set' | sed 's/^# //' | sed 's/^#//'
  exit 0
fi

ENV_FILE="${1:-.env}"
EXAMPLE_FILE="${2:-.env.example}"

bold=$(tput bold 2>/dev/null || echo "")
red=$(tput setaf 1 2>/dev/null || echo "")
green=$(tput setaf 2 2>/dev/null || echo "")
yellow=$(tput setaf 3 2>/dev/null || echo "")
reset=$(tput sgr0 2>/dev/null || echo "")

errors=0
warnings=0

echo "${bold}Auditing environment files...${reset}"
echo "  Target .env:   $ENV_FILE"
echo "  Template:      $EXAMPLE_FILE"
echo

if [ ! -f "$ENV_FILE" ]; then
  echo "${red}error: target environment file '$ENV_FILE' does not exist${reset}" >&2
  exit 1
fi

# Check for CRLF line endings
if grep -q $'\r' "$ENV_FILE"; then
  echo "${yellow}warning: '$ENV_FILE' contains CRLF (Windows) line endings. Run dos2unix.${reset}"
  warnings=$((warnings + 1))
fi

# Helper to extract variable names
extract_keys() {
  local file="$1"
  grep -vE '^\s*#' "$file" | grep -vE '^\s*$' | awk -F= '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}' | sort -u
}

mapfile -t env_keys < <(extract_keys "$ENV_FILE")

echo "Found ${#env_keys[@]} variables defined in $ENV_FILE"

# If template exists, cross-reference
if [ -f "$EXAMPLE_FILE" ]; then
  mapfile -t example_keys < <(extract_keys "$EXAMPLE_FILE")
  echo "Comparing against ${#example_keys[@]} variables in $EXAMPLE_FILE..."
  echo

  # 1. Missing keys
  missing=()
  for key in "${example_keys[@]}"; do
    if ! grep -q -x "$key" <<< "$(printf '%s\n' "${env_keys[@]}")"; then
      missing+=("$key")
    fi
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    echo "${red}${bold}Missing variables in $ENV_FILE (defined in $EXAMPLE_FILE):${reset}"
    for k in "${missing[@]}"; do
      echo "  - $k"
    done
    errors=$((errors + ${#missing[@]}))
  else
    echo "${green}✓ All variables from $EXAMPLE_FILE are present in $ENV_FILE${reset}"
  fi

  # 2. Extra keys
  extra=()
  for key in "${env_keys[@]}"; do
    if ! grep -q -x "$key" <<< "$(printf '%s\n' "${example_keys[@]}")"; then
      extra+=("$key")
    fi
  done

  if [ "${#extra[@]}" -gt 0 ]; then
    echo
    echo "${yellow}Extra variables in $ENV_FILE (not documented in $EXAMPLE_FILE):${reset}"
    for k in "${extra[@]}"; do
      echo "  + $k"
    done
  fi
fi

# 3. Check for empty values or potential default secrets
echo
echo "== Value Sanity Checks =="
empty_count=0
while IFS='=' read -r raw_key raw_val; do
  [[ "$raw_key" =~ ^[[:space:]]*# ]] && continue
  [[ -z "$raw_key" ]] && continue
  
  key=$(echo "$raw_key" | xargs)
  val=$(echo "$raw_val" | xargs)

  # Check empty
  if [ -z "$val" ]; then
    echo "  ${yellow}Empty value:${reset} $key="
    empty_count=$((empty_count + 1))
  fi

  # Check placeholder secrets
  if [[ "$key" =~ (SECRET|PASSWORD|KEY|TOKEN) ]]; then
    if [[ "$val" =~ ^(changeme|secret|admin|password|123456|test|dummy|example)$ ]]; then
      echo "  ${red}${bold}Insecure placeholder secret detected:${reset} $key=$val"
      errors=$((errors + 1))
    fi
  fi
done < "$ENV_FILE"

echo
if [ "$errors" -eq 0 ]; then
  echo "${green}${bold}Audit passed: environment configuration is healthy!${reset}"
else
  echo "${red}${bold}Audit failed: $errors error(s) found.${reset}"
fi
exit "$((errors > 0 ? 1 : 0))"
