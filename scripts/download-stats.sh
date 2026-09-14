#!/usr/bin/env bash
# Keep a lifetime download count across release pruning.
#
# downloads.json on the orphan `stats` branch is a shields.io endpoint badge
# (the README reads it through raw.githubusercontent.com; shields blocks
# github.com itself). Its extra `pruned` field is the download count of every
# release deleted so far; the badge message is that plus everything still
# published.
#
# Usage: download-stats.sh [tag[:regex]...]
#   tag    release about to be deleted; its downloads are folded into `pruned`
#   regex  fold only the assets whose name matches, for assets about to be
#          replaced (`gh release upload --clobber` deletes and re-uploads,
#          which resets the count)
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

for arg in "$@"; do
  tag="${arg%%:*}"
  re="${arg#"$tag"}"
  re="${re#:}"
  n="$(gh api "repos/$REPO/releases/tags/$tag" |
    jq --arg re "$re" '[.assets[] | select(.name | test($re)) | .download_count] | add // 0')"
  log::info "$arg: $n download(s) folded into pruned total"
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

# Matrix jobs and the two workflows update the file concurrently; the PUT is
# conditional on the sha read above, so on a conflict re-read and retry.
for attempt in 1 2 3 4 5; do
  if gh api -X PUT "repos/$REPO/contents/$FILE" --silent \
    -f branch="$BRANCH" -f message="downloads: $total" \
    -f sha="$(jq -r '.sha' <<<"$cur")" \
    -f content="$(printf '%s\n' "$new" | base64 -w0)"; then
    log::info "downloads: $pruned pruned + $live live = $total"
    exit 0
  fi
  log::warn "update conflict (attempt $attempt); retrying"
  sleep "$attempt"
  cur="$(gh api "repos/$REPO/contents/$FILE?ref=$BRANCH")"
done
log::die "could not update $FILE on $BRANCH"
