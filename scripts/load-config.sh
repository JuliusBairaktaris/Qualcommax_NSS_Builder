#!/usr/bin/env bash
# Parse builder.yml and emit GitHub Actions outputs and env entries.
#
# Required env (set by the workflow):
#   GITHUB_OUTPUT  path to outputs file (when running in Actions)
#
# Optional env:
#   BUILDER_YML    path to builder.yml (default: ./builder.yml)
#
# Outputs (when GITHUB_OUTPUT is set):
#   upstream_repo, upstream_branch
#   nss_repo, nss_branch
#   device, device_dir
#   feeds_lines           (newline-separated `src-git <name> <url>` lines)
#   release_prefix, release_keep, artifact_retention_days

set -euo pipefail

# shellcheck source=scripts/lib/log.sh
source "$(dirname -- "$0")/lib/log.sh"

BUILDER_YML="${BUILDER_YML:-builder.yml}"

[[ -f "$BUILDER_YML" ]] || log::die "$BUILDER_YML not found"
command -v yq >/dev/null || log::die "yq is required (install via apt or actions setup)"

upstream_repo="$(yq -r '.upstream.repo' "$BUILDER_YML")"
upstream_branch="$(yq -r '.upstream.branch' "$BUILDER_YML")"
nss_repo="$(yq -r '.nss_packages.repo' "$BUILDER_YML")"
nss_branch="$(yq -r '.nss_packages.branch' "$BUILDER_YML")"
device="$(yq -r '.device' "$BUILDER_YML")"
release_prefix="$(yq -r '.release.prefix' "$BUILDER_YML")"
release_keep="$(yq -r '.release.keep' "$BUILDER_YML")"
artifact_retention_days="$(yq -r '.release.artifact_retention_days' "$BUILDER_YML")"

# Validate device directory exists.
device_dir="devices/$device"
[[ -d "$device_dir" ]] || log::die "$device_dir not found (referenced by .device in $BUILDER_YML)"
[[ -f "$device_dir/config" ]] || log::die "$device_dir/config not found"

# Build feeds_lines as newline-separated `src-git <name> <url>`.
feeds_lines="$(yq -r '.feeds[] | "src-git " + .name + " " + .url' "$BUILDER_YML")"

log::info "upstream:    $upstream_repo@$upstream_branch"
log::info "nss:         $nss_repo@$nss_branch"
log::info "device:      $device  ($device_dir)"
log::info "release:     prefix=$release_prefix keep=$release_keep retention=${artifact_retention_days}d"
log::info "feeds:"
while IFS= read -r line; do printf '  %s\n' "$line"; done <<<"$feeds_lines"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "upstream_repo=$upstream_repo"
    echo "upstream_branch=$upstream_branch"
    echo "nss_repo=$nss_repo"
    echo "nss_branch=$nss_branch"
    echo "device=$device"
    echo "device_dir=$device_dir"
    echo "release_prefix=$release_prefix"
    echo "release_keep=$release_keep"
    echo "artifact_retention_days=$artifact_retention_days"
    # Multi-line value: use heredoc syntax for GITHUB_OUTPUT.
    echo "feeds_lines<<__EOF__"
    echo "$feeds_lines"
    echo "__EOF__"
  } >>"$GITHUB_OUTPUT"
fi
