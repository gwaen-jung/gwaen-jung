#!/usr/bin/env bash
# Refresh the numbers inside assets/banner.svg (stars, repos, commits, streak).
# Needs only curl, grep, sed, awk. GITHUB_TOKEN is optional (raises API limits).
set -euo pipefail

USER_NAME="${GH_USER:-gwaen-jung}"
SVG="$(dirname "$0")/../assets/banner.svg"
AUTH=()
[ -n "${GITHUB_TOKEN:-}" ] && AUTH=(-H "Authorization: Bearer $GITHUB_TOKEN")
api() { curl -fsS "${AUTH[@]}" -H "Accept: application/vnd.github+json" "$@"; }

# Read each response fully into a variable first, so grep never closes the pipe early.
profile=$(api "https://api.github.com/users/$USER_NAME")
repo_list=$(api "https://api.github.com/users/$USER_NAME/repos?per_page=100&type=owner")
commit_search=$(api -H "Accept: application/vnd.github.cloak-preview+json" \
  "https://api.github.com/search/commits?q=author:$USER_NAME&per_page=1")
calendar=$(curl -fsS "https://github.com/users/$USER_NAME/contributions")

repos=$(printf '%s\n' "$profile" | sed -n 's/.*"public_repos": *\([0-9]*\).*/\1/p' | head -n1)
stars=$(printf '%s\n' "$repo_list" | sed -n 's/.*"stargazers_count": *\([0-9]*\).*/\1/p' | awk '{s+=$1} END{print s+0}')
commits=$(printf '%s\n' "$commit_search" | sed -n 's/.*"total_count": *\([0-9]*\).*/\1/p' | head -n1)

# Streak: consecutive days with contributions, newest first; today may still be empty.
streak=$(printf '%s\n' "$calendar" \
  | grep -o 'data-date="[0-9-]*"[^>]*data-level="[0-9]"' \
  | sed -E 's/data-date="([0-9-]*)".*data-level="([0-9])"/\1 \2/' \
  | sort -r \
  | awk 'BEGIN{n=0;first=1} { if ($2>0) n++; else if (!first) exit; first=0 } END{print n+0}')

set_val() { sed -i -E "s|<!--$1-->[0-9]*<!--/$1-->|<!--$1-->$2<!--/$1-->|" "$SVG"; }
set_val stars "${stars:-0}"; set_val repos "${repos:-0}"; set_val commits "${commits:-0}"; set_val streak "${streak:-0}"
echo "stars=$stars repos=$repos commits=$commits streak=$streak"
