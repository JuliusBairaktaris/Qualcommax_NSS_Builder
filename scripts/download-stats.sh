#!/usr/bin/env bash
# Keep a lifetime download count across release pruning.
#
# downloads.json on the orphan `stats` branch is a shields.io endpoint badge
# (the README reads it through raw.githubusercontent.com; shields blocks
# github.com itself). Its extra `pruned` field is the download count of every
# release deleted so far; the badge message is that plus everything still
# published.
#
# Usage: download-stats.sh [tag...]
#   tag   release about to be deleted; its downloads are folded into `pruned`
#
# Required env: REPO (owner/name), GH_TOKEN

set -euo pipefail

# shellcheck source=scripts/lib/log.sh
source "$(dirname -- "$0")/lib/log.sh"

: "${REPO:?REPO env var required (owner/name)}"

BRANCH=stats
FILE=downloads.json

cur="$(gh api "repos/$REPO/contents/$FILE?ref=$BRANCH")"
pruned="$(jq -r '.content' <<<"$cur" | base64 -d | jq '.pruned')"
[[ "$pruned" =~ ^[0-9]+$ ]] || log::die "$FILE on $BRANCH has no numeric .pruned"

for tag in "$@"; do
  n="$(gh api "repos/$REPO/releases/tags/$tag" --jq '[.assets[].download_count] | add // 0')"
  log::info "$tag: $n download(s) folded into pruned total"
  pruned=$((pruned + n))
done

live="$(gh api "repos/$REPO/releases" --paginate \
  --jq '[.[].assets[].download_count] | add // 0' | jq -s add)"
total=$((pruned + live))

new="$(jq -nc --argjson t "$total" --argjson p "$pruned" \
  '{schemaVersion: 1, label: "Downloads", message: ($t | tostring), color: "blue", pruned: $p}')"
if [[ "$new" == "$(jq -r '.content' <<<"$cur" | base64 -d | jq -c .)" ]]; then
  log::info "downloads: $total, unchanged"
  exit 0
fi

gh api -X PUT "repos/$REPO/contents/$FILE" --silent \
  -f branch="$BRANCH" -f message="downloads: $total" \
  -f sha="$(jq -r '.sha' <<<"$cur")" \
  -f content="$(printf '%s\n' "$new" | base64 -w0)"
log::info "downloads: $pruned pruned + $live live = $total"
