#!/usr/bin/env bash
# Delete all but the newest $KEEP non-draft releases from $REPO.
#
# Required env:
#   REPO         owner/name of the GitHub repository
#   KEEP         positive integer (number of newest releases to retain)
#
# Optional env:
#   CURRENT_TAG  tag just published; never deleted even if it falls outside the keep window
#   DRY_RUN      "1" prints what would be deleted and exits 0
#   GH_TOKEN     forwarded to gh CLI (set by GitHub Actions automatically)
#
# Read input from stdin instead of calling gh:
#   RELEASES_JSON_STDIN=1 cat fixture.json | ./prune-releases.sh
# This is what the test harness uses.

set -euo pipefail

# shellcheck source=scripts/lib/log.sh
source "$(dirname -- "$0")/lib/log.sh"

: "${REPO:?REPO env var required (owner/name)}"
: "${KEEP:?KEEP env var required (positive integer)}"

CURRENT_TAG="${CURRENT_TAG:-}"
DRY_RUN="${DRY_RUN:-0}"
RELEASES_JSON_STDIN="${RELEASES_JSON_STDIN:-0}"

if ! [[ "$KEEP" =~ ^[0-9]+$ ]] || [[ "$KEEP" -lt 1 ]]; then
  log::die "KEEP must be a positive integer (got: '$KEEP')"
fi

if [[ "$RELEASES_JSON_STDIN" == "1" ]]; then
  releases_json="$(cat)"
else
  releases_json="$(gh release list \
    --repo "$REPO" \
    --limit 100 \
    --exclude-drafts \
    --json tagName,publishedAt)"
fi

# Sort newest-first by publishedAt, drop the newest $KEEP, defensively exclude $CURRENT_TAG.
mapfile -t to_delete < <(
  jq -r \
    --argjson keep "$KEEP" \
    --arg current "$CURRENT_TAG" \
    'sort_by(.publishedAt) | reverse | .[$keep:][] | select(.tagName != $current) | .tagName' \
    <<<"$releases_json"
)

total="$(jq 'length' <<<"$releases_json")"
log::info "Found $total non-draft release(s); keeping newest $KEEP."

if [[ ${#to_delete[@]} -eq 0 ]]; then
  log::info "Nothing to prune."
  exit 0
fi

log::info "Will delete the following ${#to_delete[@]} release(s):"
printf '  - %s\n' "${to_delete[@]}"

if [[ "$DRY_RUN" == "1" ]]; then
  log::info "DRY_RUN=1; no deletions performed."
  exit 0
fi

failed=0
for tag in "${to_delete[@]}"; do
  if gh release delete "$tag" --repo "$REPO" --yes --cleanup-tag; then
    log::info "deleted: $tag"
  else
    log::error "failed to delete: $tag"
    failed=$((failed + 1))
  fi
done

if [[ "$failed" -gt 0 ]]; then
  log::die "$failed release deletion(s) failed"
fi

log::info "Pruned ${#to_delete[@]} release(s)."
