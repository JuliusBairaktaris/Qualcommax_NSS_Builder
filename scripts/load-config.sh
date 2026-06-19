#!/usr/bin/env bash
# Parse builder.yml, select the variants to build for this event, and emit a
# GitHub Actions build matrix plus global settings.
#
# Required tools: yq (v4 / mikefarah), jq.
#
# Input env:
#   EVENT_NAME     github.event_name ("workflow_dispatch", "schedule", "push", ...).
#                  Anything other than workflow_dispatch builds the `scheduled: true`
#                  variants. Empty/unset is treated the same way.
#   VARIANT_INPUT  workflow_dispatch input: a variant id, or "all" (default "all").
#   BUILDER_YML    path to builder.yml (default: ./builder.yml).
#   GITHUB_OUTPUT  path to the Actions outputs file (when running in CI).
#
# Outputs (when GITHUB_OUTPUT is set):
#   matrix                   compact JSON: {"include":[{variant,device,device_dir,target,
#                            release_prefix,upstream_repo,upstream_ref,nss_repo,nss_ref,patches}, ...]}
#   release_keep             newest releases to retain per prefix
#   artifact_retention_days  Actions artifact retention
#   prefixes                 newline-separated release prefixes of every variant (for prune)

set -euo pipefail

# shellcheck source=scripts/lib/log.sh
source "$(dirname -- "$0")/lib/log.sh"

BUILDER_YML="${BUILDER_YML:-builder.yml}"
EVENT_NAME="${EVENT_NAME:-}"
VARIANT_INPUT="${VARIANT_INPUT:-all}"

[[ -f "$BUILDER_YML" ]] || log::die "$BUILDER_YML not found"
command -v yq >/dev/null || log::die "yq is required (v4/mikefarah)"
command -v jq >/dev/null || log::die "jq is required"

# Global release settings.
release_keep="$(yq -r '.release.keep' "$BUILDER_YML")"
artifact_retention_days="$(yq -r '.release.artifact_retention_days' "$BUILDER_YML")"
[[ "$release_keep" =~ ^[0-9]+$ ]] || log::die "release.keep must be an integer (got '$release_keep')"

# All variants as a JSON array.
all_variants="$(yq -o=json -I=0 '.variants' "$BUILDER_YML")"
[[ "$all_variants" != "null" && -n "$all_variants" ]] || log::die "no .variants defined in $BUILDER_YML"

# Decide which variants to build for this event.
#   - workflow_dispatch with a specific id: just that variant (forced).
#   - otherwise (schedule/push, or dispatch "all"): every variant except those a fork
#     opted out of with `scheduled: false`. check-updates then skips unchanged ones.
if [[ "$EVENT_NAME" == "workflow_dispatch" && -n "$VARIANT_INPUT" && "$VARIANT_INPUT" != "all" ]]; then
  log::info "event=workflow_dispatch -> selecting: $VARIANT_INPUT"
  selected="$(jq -c --arg id "$VARIANT_INPUT" '[ .[] | select(.id == $id) ]' <<<"$all_variants")"
else
  log::info "event=${EVENT_NAME:-<none>} -> selecting all scheduled variants"
  selected="$(jq -c '[ .[] | select(.scheduled != false) ]' <<<"$all_variants")"
fi

count="$(jq 'length' <<<"$selected")"
[[ "$count" -gt 0 ]] || log::die "no variants selected (event=$EVENT_NAME input=$VARIANT_INPUT)"

# Validate every selected variant before emitting the matrix.
while IFS= read -r row; do
  id="$(jq -r '.id' <<<"$row")"
  device="$(jq -r '.device' <<<"$row")"
  prefix="$(jq -r '.release.prefix // ""' <<<"$row")"
  dir="devices/$device"
  [[ -n "$id" && "$id" != "null" ]] || log::die "a variant is missing 'id'"
  [[ -n "$device" && "$device" != "null" ]] || log::die "variant '$id' is missing 'device'"
  [[ -d "$dir" ]] || log::die "$dir not found (variant '$id')"
  [[ -f "$dir/config" ]] || log::die "$dir/config (shared base) not found (variant '$id')"
  [[ -f "$dir/config.$id" ]] || log::die "$dir/config.$id (variant fragment) not found (variant '$id')"
  [[ -n "$prefix" ]] || log::die "variant '$id' is missing release.prefix"
done < <(jq -c '.[]' <<<"$selected")

# Build the matrix. Missing optional field (nss_packages) becomes "". Per-variant
# details not needed at the workflow-YAML level (feeds, patches, merge_prs) are read
# straight from builder.yml by prepare-build.sh, keeping the matrix lean and scalar.
matrix="$(jq -c '{
  include: [ .[] | {
    variant:        .id,
    device:         .device,
    target:         .target,
    release_prefix: .release.prefix,
    upstream_repo:  .upstream.repo,
    upstream_ref:   (.upstream.ref | tostring),
    nss_repo:       (.nss_packages.repo // ""),
    nss_ref:        ((.nss_packages.ref // "") | tostring)
  } ]
}' <<<"$selected")"

# Every variant's prefix (not just the selected ones) so prune can trim each group.
prefixes="$(yq -r '.variants[].release.prefix' "$BUILDER_YML")"

log::info "release: keep=$release_keep retention=${artifact_retention_days}d"
log::info "selected $count variant(s):"
jq -r '.include[] | "  - \(.variant): \(.upstream_repo)@\(.upstream_ref) -> \(.target) [\(.release_prefix)]"' <<<"$matrix"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "matrix=$matrix"
    echo "release_keep=$release_keep"
    echo "artifact_retention_days=$artifact_retention_days"
    echo "prefixes<<__EOF__"
    echo "$prefixes"
    echo "__EOF__"
  } >>"$GITHUB_OUTPUT"
fi
