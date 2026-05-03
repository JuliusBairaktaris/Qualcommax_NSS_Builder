#!/usr/bin/env bash
# Prepare an OpenWrt source tree for build:
#   - apply patches from $BUILDER_REPO/patches/*.patch (if any)
#   - append custom feeds from FEEDS_LINES
#   - run feeds update/install
#   - copy device .config and run defconfig
#   - disable bundling of custom feeds into the image
#
# Required env:
#   OPENWRT_DIR    path to checked-out OpenWrt source (working dir is set here)
#   BUILDER_REPO   path to this repo
#   DEVICE_DIR     path to devices/<id>/  (relative to BUILDER_REPO)
#   FEEDS_LINES    newline-separated `src-git <name> <url>` lines
#
# Optional env:
#   COMMON_FILES   path to common/files (default: $BUILDER_REPO/common/files)

set -euo pipefail

# shellcheck source=scripts/lib/log.sh
source "$(dirname -- "$0")/lib/log.sh"

: "${OPENWRT_DIR:?OPENWRT_DIR required}"
: "${BUILDER_REPO:?BUILDER_REPO required}"
: "${DEVICE_DIR:?DEVICE_DIR required}"
: "${FEEDS_LINES:?FEEDS_LINES required}"

COMMON_FILES="${COMMON_FILES:-$BUILDER_REPO/common/files}"

cd "$OPENWRT_DIR"

# 1. Apply patches.
patches_dir="$BUILDER_REPO/patches"
if compgen -G "$patches_dir/*.patch" >/dev/null; then
  log::info "Applying patches from $patches_dir"
  while IFS= read -r patch; do
    log::info "  $patch"
    git apply --verbose "$patch"
  done < <(find "$patches_dir" -maxdepth 1 -type f -name '*.patch' | sort)
else
  log::info "No patches to apply."
fi

# 2. Configure feeds.
[[ -f feeds.conf ]] || cp feeds.conf.default feeds.conf

log::info "Appending custom feeds:"
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  log::info "  $line"
  echo "$line" >>feeds.conf
done <<<"$FEEDS_LINES"

# Update + install each custom feed individually so failures are obvious,
# then update + install everything else.
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  feed_name="$(awk '{print $2}' <<<"$line")"
  log::info "Updating feed: $feed_name"
  ./scripts/feeds update "$feed_name"
  ./scripts/feeds install -a -p "$feed_name"
done <<<"$FEEDS_LINES"

log::info "Updating + installing all feeds"
./scripts/feeds update -a
./scripts/feeds install -a

# 3. Drop in device .config and resolve.
log::info "Loading device config: $DEVICE_DIR/config"
cp "$BUILDER_REPO/$DEVICE_DIR/config" .config
make defconfig

# 4. Disable bundling of custom feeds into the image (we declared them as
#    src-git but don't want every package shipped by default).
log::info "Disabling CONFIG_FEED_<custom> entries"
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  feed_name="$(awk '{print $2}' <<<"$line")"
  sed -i "s/^CONFIG_FEED_${feed_name}=.*/# CONFIG_FEED_${feed_name} is not set/" .config || true
done <<<"$FEEDS_LINES"
sed -i 's/^CONFIG_FEED_luci_extra=.*/# CONFIG_FEED_luci_extra is not set/' .config || true

# 5. Copy custom files (common first, then device-specific so device wins).
log::info "Applying overlay files"
mkdir -p files

if [[ -d "$COMMON_FILES" ]]; then
  log::info "  common: $COMMON_FILES"
  rsync -a "$COMMON_FILES/" files/
fi

if [[ -d "$BUILDER_REPO/$DEVICE_DIR/files" ]]; then
  log::info "  device: $BUILDER_REPO/$DEVICE_DIR/files"
  rsync -a "$BUILDER_REPO/$DEVICE_DIR/files/" files/
fi

# Lock down sshd_config if shipped.
if [[ -f files/etc/ssh/sshd_config ]]; then
  chmod 0600 files/etc/ssh/sshd_config
fi

log::info "Build environment ready."
