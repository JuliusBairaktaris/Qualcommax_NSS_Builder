# Customizing the build

All knobs live in the **`env:` block of [`.github/workflows/build.yml`](../.github/workflows/build.yml)**,
the **[shared `.config`](../devices/common/config)** plus its per-device
companion, and the overlay directories. This page shows what each one does.

## Build parameters (`build.yml` → `env:`)

```yaml
env:
  UPSTREAM_REPO: JuliusBairaktaris/openwrt-ppe-nss   # OpenWrt source tree
  UPSTREAM_REF: ppe-nss                               # branch, tag, or 40-char SHA
  NSS_REPO: JuliusBairaktaris/nss-packages            # nss-firmware feed (blank to disable)
  NSS_REF: edma-nss
  VARIANT: ppe-nss                                    # selects files.<variant>, patches/*/<variant>
  RELEASE_PREFIX: ppe-nss                             # tag = <prefix>-<ts>-<run id>
  MESH_RELEASE_PREFIX: ppe-nss-mesh                   # same, for the mesh flavour
  KEEP: "2"                                           # newest releases to retain, per prefix
  FEEDS: |
    src-git nss https://github.com/JuliusBairaktaris/nss-packages.git;edma-nss
    src-git luci https://github.com/JuliusBairaktaris/luci.git;luci-app-ppe-qos
```

Which devices get built is the `build` job's matrix, one entry per
`devices/<id>/` directory:

```yaml
    strategy:
      matrix:
        device: [xiaomi_ax3600, ipq807x-1g, ipq807x-512m, ipq807x-256m, ipq60xx-1g, ipq60xx-512m]
        flavour: [default, mesh]
        include:
          - flavour: mesh
            config_fragment: devices/common/config.mesh
```

The subtarget is part of each group's config (`CONFIG_TARGET_qualcommax_ipq807x=y`
or `CONFIG_TARGET_qualcommax_ipq60xx=y`), not of the shared one, so ipq807x and
ipq60xx groups build side by side.

The second axis is the **flavour**: every group is built twice, once plain and
once for 802.11s mesh, and each flavour gets its own release
(`RELEASE_PREFIX` / `MESH_RELEASE_PREFIX`). A flavour is nothing but a `.config`
fragment appended after the common and device configs — `CONFIG_FRAGMENT`,
which `prepare-build.sh` reads — so it wins on any symbol they also set. Mesh
needs it because its NSS firmware line (11.4.0.5, the last one that accepts a
mesh interface) is image-wide. The overlay files are
unaffected: both flavours use `files.$VARIANT`.

Adding a device to a group is one
`CONFIG_TARGET_DEVICE_qualcommax_<subtarget>_DEVICE_<id>=y` line in the group
config of its subtarget and RAM size.

`CONFIG_TARGET_PER_DEVICE_ROOTFS=y` is what keeps each image to its own device
packages; without it every image in a group carries every other board's.

When the build runs depends on the trigger:
- **schedule** → `check` skips the build when the upstream is unchanged since the last release
  (this is the "rebuild when upstream moves" path).
- **push** → always rebuilt — a push to this repo means the config, overlays, or scripts changed,
  so the image must be regenerated.
- **Run workflow** (`workflow_dispatch`) → always rebuilt.

## Device `.config`

The `.config` is assembled from two files: everything device-independent is in
[`devices/common/config`](../devices/common/config), and `devices/<id>/config`
adds the device list and any board-specific package
pruning. `prepare-build.sh` concatenates them (the device file wins on a symbol
set in both) and runs `make defconfig`. To change something, edit in a real
OpenWrt checkout and diff back:

```sh
git clone --branch ppe-nss https://github.com/JuliusBairaktaris/openwrt-ppe-nss openwrt
cat devices/common/config devices/xiaomi_ax3600/config > openwrt/.config
cd openwrt && make menuconfig
./scripts/diffconfig.sh > /tmp/full.config        # minimal .config (deltas only)
# then split the delta back over devices/common/config and devices/<id>/config
```

A symbol whose dependencies are unmet is dropped silently by `make defconfig`,
which is how an image ships without an option someone asked for. Every
requested `=y` symbol is therefore re-checked against the resolved `.config`,
and a missing one fails the build.

Anything a board does not have belongs in its own config, never in the shared
one: `DEVICE_PACKAGES` pulls in each board's ath10k firmware, USB and 10G PHY
support, and disabling those globally ships a broken image for every board that
does have the hardware.

## Routed multicast

Same-subnet multicast is bridged in hardware through switchdev. Routed
multicast (IPTV WAN→LAN) needs a daemon that fills the kernel multicast
routing table, which the image does not bundle. Add
`CONFIG_PACKAGE_igmpproxy=y` (or `smcroute`) to `devices/common/config` and
ship your own `/etc/config/igmpproxy` for your topology. The mroute kernel
options it needs are already set.

## Custom feeds

Each `src-git <name> <url>` line in `FEEDS` is appended to `feeds.conf` and updated/installed
individually. The corresponding `CONFIG_FEED_<name>` is then set to `n` so you don't bundle every
package from the feed — only what you explicitly enable in `.config` ships.

## Rootfs overlay

Four overlay layers, applied in order (later wins), each optional:

1. `devices/common/files/` — every image
2. `devices/common/files.ppe-nss/` — every image, variant-specific
3. `devices/<id>/files/` — one device
4. `devices/<id>/files.ppe-nss/` — one device, variant-specific

Anything under these is copied to the image root, preserving paths. Special handling:
- `etc/ssh/sshd_config` is `chmod 0600`'d automatically
- `etc/uci-defaults/<name>` files run once on first boot, then are deleted
- `etc/rc.local` runs on every boot

## Cron schedule

GitHub Actions requires `cron:` values to be static. Edit [`.github/workflows/build.yml`](../.github/workflows/build.yml):

```yaml
on:
  schedule:
    - cron: "0 */2 * * *"            # every 2 hours
```

Use [crontab.guru](https://crontab.guru) if you're unsure.

## Disabling caching

This build does not use `actions/cache` and explicitly sets `# CONFIG_CCACHE is not set` in the
config. ccache without persistent storage is a no-op on fresh runners, and `actions/cache` for
OpenWrt's multi-GB build dir is a footgun (easily corrupts mid-build).

## Disabling the schedule

If you only want manual builds, remove the `schedule:` block from `build.yml` (keep
`workflow_dispatch` and `push`).
