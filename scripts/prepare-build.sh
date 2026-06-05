#!/usr/bin/env bash
# Prepare a checked-out OpenWrt tree for one build variant:
#   0. merge any OpenWrt PRs (variant.merge_prs) onto the tree, fresh, every build
#   1. apply shared patches/*.patch, then variant patches/<subdir>/*.patch
#   2. append the variant's custom feeds and run feeds update/install
#   3. assemble .config from the device base + variant fragment, run defconfig
#   4. disable bundling of custom feeds into the image
#   5. layer overlay files: common -> device -> device/variant (most specific wins)
#
# Required env:
#   OPENWRT_DIR   path to the checked-out OpenWrt source (a git work tree)
#   BUILDER_REPO  path to this repo
#   VARIANT       variant id (matches builder.yml .variants[].id and devices/<d>/config.<id>)
#   DEVICE        device id (matches devices/<id>/)
#
# Optional env:
#   BUILDER_YML   path to builder.yml (default: $BUILDER_REPO/builder.yml)
#   COMMON_FILES  path to common/files (default: $BUILDER_REPO/common/files)

set -euo pipefail

# shellcheck source=scripts/lib/log.sh
source "$(dirname -- "$0")/lib/log.sh"

: "${OPENWRT_DIR:?OPENWRT_DIR required}"
: "${BUILDER_REPO:?BUILDER_REPO required}"
: "${VARIANT:?VARIANT required}"
: "${DEVICE:?DEVICE required}"

BUILDER_YML="${BUILDER_YML:-$BUILDER_REPO/builder.yml}"
COMMON_FILES="${COMMON_FILES:-$BUILDER_REPO/common/files}"
DEVICE_DIR="$BUILDER_REPO/devices/$DEVICE"

command -v yq >/dev/null || log::die "yq is required"
[[ -f "$BUILDER_YML" ]] || log::die "$BUILDER_YML not found"
[[ -f "$DEVICE_DIR/config" ]] || log::die "$DEVICE_DIR/config (shared base) not found"
[[ -f "$DEVICE_DIR/config.$VARIANT" ]] || log::die "$DEVICE_DIR/config.$VARIANT (fragment) not found"

# Per-variant settings, read straight from builder.yml.
mapfile -t MERGE_PRS < <(yq -r ".variants[] | select(.id == \"$VARIANT\") | .merge_prs[]?" "$BUILDER_YML")
PATCHES_SUBDIR="$(yq -r ".variants[] | select(.id == \"$VARIANT\") | .patches // \"\"" "$BUILDER_YML")"
FEEDS_LINES="$(yq -r ".variants[] | select(.id == \"$VARIANT\") | .feeds[]? | \"src-git \" + .name + \" \" + .url" "$BUILDER_YML")"

cd "$OPENWRT_DIR"

# 0. Merge OpenWrt PRs onto the current tree. Kept *uncommitted* (--no-commit) so HEAD —
#    and therefore SOURCE_DATE_EPOCH, derived from HEAD later — stays pinned to the
#    upstream commit we checked out, while the work tree carries the merged changes.
if [[ ${#MERGE_PRS[@]} -gt 0 ]]; then
  git config user.email "builder@github"
  git config user.name "builder"
  for pr in "${MERGE_PRS[@]}"; do
    [[ -n "$pr" ]] || continue
    log::info "Merging openwrt PR #$pr onto $(git rev-parse --short HEAD)"
    git fetch --no-tags origin "pull/$pr/head"
    if ! git merge --no-commit --no-ff FETCH_HEAD; then
      git merge --abort || true
      log::die "PR #$pr does not merge cleanly onto the current upstream; wait for the PR to be rebased"
    fi
  done
fi

# 1. Apply patches: shared patches/*.patch, then variant patches/<subdir>/*.patch.
apply_patches_in() {
  local dir="$1"
  compgen -G "$dir/*.patch" >/dev/null || return 0
  log::info "Applying patches from $dir"
  while IFS= read -r patch; do
    log::info "  $patch"
    git apply --verbose "$patch"
  done < <(find "$dir" -maxdepth 1 -type f -name '*.patch' | sort)
}
apply_patches_in "$BUILDER_REPO/patches"
if [[ -n "$PATCHES_SUBDIR" ]]; then
  apply_patches_in "$BUILDER_REPO/patches/$PATCHES_SUBDIR"
fi

# 2. Configure feeds.
[[ -f feeds.conf ]] || cp feeds.conf.default feeds.conf

if [[ -n "$FEEDS_LINES" ]]; then
  log::info "Appending custom feeds:"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    log::info "  $line"
    echo "$line" >>feeds.conf
  done <<<"$FEEDS_LINES"

  # Update + install each custom feed individually so failures are obvious.
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    feed_name="$(awk '{print $2}' <<<"$line")"
    log::info "Updating feed: $feed_name"
    ./scripts/feeds update "$feed_name"
    ./scripts/feeds install -a -p "$feed_name"
  done <<<"$FEEDS_LINES"
fi

log::info "Updating + installing all feeds"
./scripts/feeds update -a
./scripts/feeds install -a

# 3. Assemble .config from the shared base + variant fragment, then resolve.
log::info "Assembling .config from devices/$DEVICE/{config, config.$VARIANT}"
cat "$DEVICE_DIR/config" "$DEVICE_DIR/config.$VARIANT" >.config
make defconfig

# 4. Disable bundling of custom feeds into the image (declared src-git, but we only want
#    the packages explicitly enabled in .config — not every package in the feed).
if [[ -n "$FEEDS_LINES" ]]; then
  log::info "Disabling CONFIG_FEED_<custom> entries"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    feed_name="$(awk '{print $2}' <<<"$line")"
    sed -i "s/^CONFIG_FEED_${feed_name}=.*/# CONFIG_FEED_${feed_name} is not set/" .config || true
  done <<<"$FEEDS_LINES"
fi
sed -i 's/^CONFIG_FEED_luci_extra=.*/# CONFIG_FEED_luci_extra is not set/' .config || true

# 5. Layer overlay files: common -> device -> device/variant (most specific wins).
log::info "Applying overlay files"
mkdir -p files
for src in "$COMMON_FILES" "$DEVICE_DIR/files" "$DEVICE_DIR/files.$VARIANT"; do
  if [[ -d "$src" ]]; then
    log::info "  $src"
    rsync -a "$src/" files/
  fi
done

# Lock down sshd_config if shipped.
if [[ -f files/etc/ssh/sshd_config ]]; then
  chmod 0600 files/etc/ssh/sshd_config
fi

log::info "Build environment ready for variant '$VARIANT' on device '$DEVICE'."
