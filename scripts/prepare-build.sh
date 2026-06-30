#!/usr/bin/env bash
# Prepare a checked-out OpenWrt tree for the build:
#   1. append the custom feeds and run feeds update/install
#   2. assemble .config from the device config, run defconfig
#   3. disable bundling of custom feeds into the image
#   4. layer overlay files: device -> device/variant (most specific wins)
#
# Required env:
#   OPENWRT_DIR   path to the checked-out OpenWrt source (a git work tree)
#   BUILDER_REPO  path to this repo
#   VARIANT       variant id (selects devices/<device>/files.<variant>)
#   DEVICE        device id (selects devices/<device>/)
#
# Optional env:
#   FEEDS         newline-separated `src-git <name> <url>` lines to append to feeds.conf

set -euo pipefail

# shellcheck source=scripts/lib/log.sh
source "$(dirname -- "$0")/lib/log.sh"

: "${OPENWRT_DIR:?OPENWRT_DIR required}"
: "${BUILDER_REPO:?BUILDER_REPO required}"
: "${VARIANT:?VARIANT required}"
: "${DEVICE:?DEVICE required}"

FEEDS="${FEEDS:-}"
DEVICE_DIR="$BUILDER_REPO/devices/$DEVICE"

[[ -f "$DEVICE_DIR/config" ]] || log::die "$DEVICE_DIR/config not found"

cd "$OPENWRT_DIR"

# 1. Configure feeds.
[[ -f feeds.conf ]] || cp feeds.conf.default feeds.conf

if [[ -n "$FEEDS" ]]; then
  log::info "Appending custom feeds:"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    log::info "  $line"
    echo "$line" >>feeds.conf
    # Update + install each custom feed individually so failures are obvious.
    feed_name="$(awk '{print $2}' <<<"$line")"
    log::info "Updating feed: $feed_name"
    ./scripts/feeds update "$feed_name"
    ./scripts/feeds install -a -p "$feed_name"
  done <<<"$FEEDS"
fi

log::info "Updating + installing all feeds"
./scripts/feeds update -a
./scripts/feeds install -a

# 2. Assemble .config from the device config, then resolve.
log::info "Assembling .config from devices/$DEVICE/config"
cp "$DEVICE_DIR/config" .config
make defconfig

# 3. Disable bundling of custom feeds into the image (declared src-git, but we only want
#    the packages explicitly enabled in .config — not every package in the feed).
if [[ -n "$FEEDS" ]]; then
  log::info "Disabling CONFIG_FEED_<custom> entries"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    feed_name="$(awk '{print $2}' <<<"$line")"
    sed -i "s/^CONFIG_FEED_${feed_name}=.*/# CONFIG_FEED_${feed_name} is not set/" .config || true
  done <<<"$FEEDS"
fi
sed -i 's/^CONFIG_FEED_luci_extra=.*/# CONFIG_FEED_luci_extra is not set/' .config || true

# 4. Layer overlay files: device -> device/variant (most specific wins).
log::info "Applying overlay files"
mkdir -p files
for src in "$DEVICE_DIR/files" "$DEVICE_DIR/files.$VARIANT"; do
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
