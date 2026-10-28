#!/usr/bin/env bash
# Clean up merged local git branches and prune stale remote tracking references.
#
# Usage:
#   scripts/git-cleanup.sh [options]
#
# Options:
#   -a, --apply       Execute deletion (default is dry-run mode)
#   -b, --base <name> Base branch to check against (default: main or master)
#   -h, --help        Show this help message
set -euo pipefail

APPLY=0
BASE_BRANCH=""

while [ $# -gt 0 ]; do
  case "$1" in
    -a|--apply)
      APPLY=1; shift ;;
    -b|--base)
      BASE_BRANCH="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,/^set -euo pipefail/p' "$0" | grep -v '^set' | sed 's/^# //' | sed 's/^#//'
      exit 0 ;;
    *)
      echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: must be run inside a git repository" >&2
  exit 1
fi

bold=$(tput bold 2>/dev/null || echo "")
green=$(tput setaf 2 2>/dev/null || echo "")
yellow=$(tput setaf 3 2>/dev/null || echo "")
reset=$(tput sgr0 2>/dev/null || echo "")

# Auto-detect base branch if not provided
if [ -z "$BASE_BRANCH" ]; then
  if git show-ref --verify --quiet refs/heads/main; then
    BASE_BRANCH="main"
  elif git show-ref --verify --quiet refs/heads/master; then
    BASE_BRANCH="master"
  else
    BASE_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  fi
fi

current_branch=$(git rev-parse --abbrev-ref HEAD)

echo "== Git Repository Maintenance =="
echo "  Current branch: $current_branch"
echo "  Base branch:    $BASE_BRANCH"
if [ "$APPLY" -eq 1 ]; then
  echo "  Mode:           ${green}${bold}APPLY${reset}"
else
  echo "  Mode:           ${yellow}${bold}DRY-RUN (pass --apply to execute)${reset}"
fi
echo

# 1. Prune remote references
echo "== 1. Pruning remote tracking branches =="
if [ "$APPLY" -eq 1 ]; then
  git remote prune origin 2>/dev/null || git fetch --prune 2>/dev/null || echo "  (no remote configured)"
else
  echo "  [dry-run] would run: git fetch --prune"
fi

# 2. Identify merged local branches
echo
echo "== 2. Identifying merged local branches =="
mapfile -t merged_branches < <(git branch --merged "$BASE_BRANCH" | sed 's/^[ *]*//' | grep -vE "^($BASE_BRANCH|master|main|develop|dev|\*)$" || true)

if [ "${#merged_branches[@]}" -eq 0 ]; then
  echo "  no merged feature branches found to clean"
else
  echo "  found ${#merged_branches[@]} merged branch(es):"
  for b in "${merged_branches[@]}"; do
    if [ "$b" = "$current_branch" ]; then
      echo "  - $b (skipped: currently checked out)"
      continue
    fi

    if [ "$APPLY" -eq 1 ]; then
      git branch -d "$b" 2>/dev/null && echo "  ${green}deleted $b${reset}" || echo "  failed to delete $b"
    else
      echo "  [dry-run] would delete: $b"
    fi
  done
fi

# 3. Compact git database
echo
echo "== 3. Repository optimization =="
if [ "$APPLY" -eq 1 ]; then
  git gc --auto --quiet
  echo "  ${green}git garbage collection complete${reset}"
else
  echo "  [dry-run] would run: git gc --auto"
fi

echo
echo "done"
