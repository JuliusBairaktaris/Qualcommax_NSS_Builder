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

# [{tag, re}]; an empty regex matches every asset of the tag.
folds='[]'
for arg in "$@"; do
  tag="${arg%%:*}"
  re="${arg#"$tag"}"
  folds="$(jq -c --arg t "$tag" --arg re "${re#:}" '. + [{tag: $t, re: $re}]' <<<"$folds")"
done

releases="$(gh api "repos/$REPO/releases" --paginate | jq -s '[.[][]]')"
folded="$(jq --argjson f "$folds" '
  [.[] | .tag_name as $t | .assets[] | .name as $n
   | select(any($f[]; .tag == $t and (.re as $re | $n | test($re)))) | .download_count] | add // 0' <<<"$releases")"
# Folded assets stay published until the caller deletes them, so `live`
# leaves them out.
live="$(jq --argjson f "$folds" '
  [.[] | .tag_name as $t | .assets[] | .name as $n
   | select(any($f[]; .tag == $t and (.re as $re | $n | test($re))) | not) | .download_count] | add // 0' <<<"$releases")"
[[ $# -eq 0 ]] || log::info "$folded download(s) on $* folded into pruned total"

# Matrix jobs and the two workflows update the file concurrently; the PUT is
# conditional on the sha read here, so on a conflict start over.
for attempt in 1 2 3 4 5; do
  cur="$(gh api "repos/$REPO/contents/$FILE?ref=$BRANCH")"
  old="$(jq -r '.content' <<<"$cur" | base64 -d | jq -c .)"
  pruned="$(jq '.pruned' <<<"$old")"
  [[ "$pruned" =~ ^[0-9]+$ ]] || log::die "$FILE on $BRANCH has no numeric .pruned"
  pruned=$((pruned + folded))
  total=$((pruned + live))

  new="$(jq -nc --argjson t "$total" --argjson p "$pruned" \
    '{schemaVersion: 1, label: "Downloads", message: ($t | tostring), color: "blue", pruned: $p}')"
  if [[ "$new" == "$old" ]]; then
    log::info "downloads: $total, unchanged"
    exit 0
  fi
  if gh api -X PUT "repos/$REPO/contents/$FILE" --silent \
    -f branch="$BRANCH" -f message="downloads: $total" \
    -f sha="$(jq -r '.sha' <<<"$cur")" \
    -f content="$(printf '%s\n' "$new" | base64 -w0)"; then
    log::info "downloads: $pruned pruned + $live live = $total"
    exit 0
  fi
  log::warn "update conflict (attempt $attempt); retrying"
  sleep "$attempt"
done
log::die "could not update $FILE on $BRANCH"
