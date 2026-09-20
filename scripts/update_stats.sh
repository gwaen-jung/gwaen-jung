#!/usr/bin/env bash
# Refresh the numbers inside assets/banner.svg (stars, repos, commits, streak).
# Needs only curl, grep, sed, awk. GITHUB_TOKEN is optional (raises API limits).
set -euo pipefail

USER_NAME="${GH_USER:-gwaen-jung}"
SVG="$(dirname "$0")/../assets/banner.svg"
AUTH=()
[ -n "${GITHUB_TOKEN:-}" ] && AUTH=(-H "Authorization: Bearer $GITHUB_TOKEN")
api() { curl -fsS "${AUTH[@]}" -H "Accept: application/vnd.github+json" "$@"; }

repos=$(api "https://api.github.com/users/$USER_NAME" | grep -m1 '"public_repos"' | grep -o '[0-9]\+')
stars=$(api "https://api.github.com/users/$USER_NAME/repos?per_page=100&type=owner" \
  | grep '"stargazers_count"' | grep -o '[0-9]\+' | awk '{s+=$1} END{print s+0}')
commits=$(api -H "Accept: application/vnd.github.cloak-preview+json" \
  "https://api.github.com/search/commits?q=author:$USER_NAME&per_page=1" \
  | grep -m1 '"total_count"' | grep -o '[0-9]\+')

# Streak: consecutive days with contributions, newest first; today may still be empty.
streak=$(curl -fsS "https://github.com/users/$USER_NAME/contributions" \
  | grep -o 'data-date="[0-9-]*"[^>]*data-level="[0-9]"' \
  | sed -E 's/data-date="([0-9-]*)".*data-level="([0-9])"/\1 \2/' \
  | sort -r \
  | awk 'BEGIN{n=0;first=1} { if ($2>0) n++; else if (!first) exit; first=0 } END{print n+0}')

set_val() { sed -i -E "s|<!--$1-->[0-9]*<!--/$1-->|<!--$1-->$2<!--/$1-->|" "$SVG"; }
set_val stars "$stars"; set_val repos "$repos"; set_val commits "$commits"; set_val streak "$streak"
echo "stars=$stars repos=$repos commits=$commits streak=$streak"
