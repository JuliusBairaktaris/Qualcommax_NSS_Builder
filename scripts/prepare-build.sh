#!/usr/bin/env bash
# Prepare a checked-out OpenWrt tree for the build:
#   1. append the custom feeds and run feeds update/install
#   2. assemble .config from the common + device configs, run defconfig
#   3. disable bundling of custom feeds into the image
#   4. layer overlay files: common -> device, each with its variant on top
#      (most specific wins)
#
# Required env:
#   OPENWRT_DIR   path to the checked-out OpenWrt source (a git work tree)
#   BUILDER_REPO  path to this repo
#   VARIANT       variant id (selects devices/<device>/files.<variant>)
#   DEVICE        device id (selects devices/<device>/)
#
# Optional env:
#   FEEDS         newline-separated `src-git <name> <url>` lines for feeds.conf;
#                 a name already in feeds.conf replaces that feed (fork stand-in)
#   CONFIG_FRAGMENT  repo-relative .config fragment appended last (flavour, e.g. mesh)
#   COMMON        devices/<COMMON> holding the shared config and overlays (default: common)

set -euo pipefail

# shellcheck source=scripts/lib/log.sh
source "$(dirname -- "$0")/lib/log.sh"

: "${OPENWRT_DIR:?OPENWRT_DIR required}"
: "${BUILDER_REPO:?BUILDER_REPO required}"
: "${VARIANT:?VARIANT required}"
: "${DEVICE:?DEVICE required}"

FEEDS="${FEEDS:-}"
CONFIG_FRAGMENT="${CONFIG_FRAGMENT:-}"
COMMON_DIR="$BUILDER_REPO/devices/${COMMON:-common}"
DEVICE_DIR="$BUILDER_REPO/devices/$DEVICE"

[[ -f "$DEVICE_DIR/config" ]] || log::die "$DEVICE_DIR/config not found"
[[ -f "$COMMON_DIR/config" ]] || log::die "$COMMON_DIR/config not found"

# Least to most specific; the last file wins on a symbol set in several.
CONFIGS=("$COMMON_DIR/config" "$DEVICE_DIR/config")
if [[ -n "$CONFIG_FRAGMENT" ]]; then
  [[ -f "$BUILDER_REPO/$CONFIG_FRAGMENT" ]] ||
    log::die "CONFIG_FRAGMENT $CONFIG_FRAGMENT not found in $BUILDER_REPO"
  CONFIGS+=("$BUILDER_REPO/$CONFIG_FRAGMENT")
fi

cd "$OPENWRT_DIR"

# 1. Configure feeds.
[[ -f feeds.conf ]] || cp feeds.conf.default feeds.conf

if [[ -n "$FEEDS" ]]; then
  log::info "Appending custom feeds:"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    log::info "  $line"
    # Idempotent: this script is re-run over an existing tree, and a plain
    # append duplicates every custom feed on each pass - which then makes
    # `feeds update` fetch the same feed repeatedly under one name.
    feed_name="$(awk '{print $2}' <<<"$line")"
    if ! grep -qxF "$line" feeds.conf; then
      # Same name as an existing feed: the line replaces it, so a fork can
      # stand in for a default feed.
      sed -i -E "/^src-\S+[[:space:]]+${feed_name}[[:space:]]/d" feeds.conf
      echo "$line" >>feeds.conf
    fi
    # Update + install each custom feed individually so failures are obvious.
    log::info "Updating feed: $feed_name"
    ./scripts/feeds update "$feed_name"
    ./scripts/feeds install -a -p "$feed_name"
  done <<<"$FEEDS"
fi

log::info "Updating + installing all feeds"
./scripts/feeds update -a
./scripts/feeds install -a

# 1b. Apply local patches to feed packages
#     (patches/feeds/<variant>/<feed>/*.patch, paths relative to the feed
#     root), so a patch rides only the flavour it is for.
shopt -s nullglob
for p in "$BUILDER_REPO/patches/feeds/$VARIANT"/*/*.patch; do
  feed="feeds/$(basename "$(dirname "$p")")"
  if patch -p1 -d "$feed" --dry-run --forward <"$p" >/dev/null 2>&1; then
    log::info "Patching $feed with $(basename "$p")"
    patch -p1 -d "$feed" --forward <"$p"
  elif patch -p1 -d "$feed" --dry-run --reverse <"$p" >/dev/null 2>&1; then
    log::info "Skipping $(basename "$p") (already applied)"
  else
    log::die "$(basename "$p") does not apply to $feed"
  fi
done
shopt -u nullglob

# 2. Assemble .config from the common + device configs, then resolve.
log::info "Assembling .config from ${CONFIGS[*]#"$BUILDER_REPO"/}"
cat "${CONFIGS[@]}" >.config
make defconfig

# 2b. Verify defconfig honoured the device config. Kconfig silently drops a
#     requested symbol whose dependencies are unmet, which is how images have
#     shipped without pinned options before (ccache, ramoops, the NSS firmware
#     version) - a build that quietly leaves a package out is worse than one
#     that stops. Only the requested-on symbols are asserted: a requested "=n"
#     legitimately comes back on when another selected package depends on it.
log::info "Verifying defconfig kept the requested symbols"
dropped=()
while IFS= read -r req; do
  grep -qxF "$req" .config || dropped+=("$req")
done < <(cat "${CONFIGS[@]}" |
  grep -E '^CONFIG_[A-Za-z0-9_-]+=' |
  awk -F= '{ last[$1] = $0 } END { for (s in last) print last[s] }' |
  grep -vE '=n$')

if ((${#dropped[@]})); then
  log::error "defconfig dropped ${#dropped[@]} requested symbol(s) for device '$DEVICE':"
  printf '  %s\n' "${dropped[@]}" >&2
  log::die "add the missing dependency or remove the line - do not ship a silently reduced image"
fi

# 3. Disable bundling of custom feeds into the image (declared src-git, but we only want
#    the packages explicitly enabled in .config — not every package in the feed).
if [[ -n "$FEEDS" ]]; then
  log::info "Disabling CONFIG_FEED_<custom> entries"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    feed_name="$(awk '{print $2}' <<<"$line")"
    # A fork standing in for a default feed keeps that feed's distfeed entry.
    grep -qE "^src-\S+[[:space:]]+${feed_name}[[:space:]]" feeds.conf.default && continue
    sed -i "s/^CONFIG_FEED_${feed_name}=.*/# CONFIG_FEED_${feed_name} is not set/" .config || true
  done <<<"$FEEDS"
fi
sed -i 's/^CONFIG_FEED_luci_extra=.*/# CONFIG_FEED_luci_extra is not set/' .config || true

# 4. Layer overlay files: common -> device, variant on top of each (most
#    specific wins).
log::info "Applying overlay files"
mkdir -p files
for src in "$COMMON_DIR/files" "$COMMON_DIR/files.$VARIANT" \
  "$DEVICE_DIR/files" "$DEVICE_DIR/files.$VARIANT"; do
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
