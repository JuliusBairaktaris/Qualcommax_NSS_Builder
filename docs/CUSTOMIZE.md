# Customizing the build

All knobs live in the **`env:` block of [`.github/workflows/build.yml`](../.github/workflows/build.yml)**,
the **[shared `.config`](../devices/common/config)** plus its per-device
companion, and the overlay directories. This page shows what each one does.

## Build parameters (`build.yml` → `env:`)

```yaml
env:
  UPSTREAM_REPO: JuliusBairaktaris/openwrt-nss-edma   # OpenWrt source tree
  UPSTREAM_REF: nss-edma-rework                       # branch, tag, or 40-char SHA
  NSS_REPO: JuliusBairaktaris/nss-packages            # NSS packages repo (blank to disable)
  NSS_REF: edma-nss
  TARGET: qualcommax/ipq807x                          # bin/targets/<target>/
  VARIANT: edma-nss                                   # selects devices/<id>/files.<variant>
  RELEASE_PREFIX: edma-nss                            # tag = <prefix>-<ts>-<run id>
  KEEP: "2"                                           # newest releases to retain
  FEEDS: "src-git nss https://github.com/JuliusBairaktaris/nss-packages.git;edma-nss"
```

Which devices get built is the `build` job's matrix, one entry per
`devices/<id>/` directory:

```yaml
    strategy:
      matrix:
        device: [xiaomi_ax3600, ipq807x-1g, ipq807x-512m, ipq807x-256m]
```

A group exists per memory profile, because the ath11k and NSS profiles are
compile-time and image-wide. Adding a device to a group is one
`CONFIG_TARGET_DEVICE_qualcommax_ipq807x_DEVICE_<id>=y` line in that group's
config — the group whose profile matches the board's RAM.

Getting that right is on you. `kmod-ath11k` carries per-board profile selects,
but they key off the single-profile choice symbol
(`CONFIG_TARGET_qualcommax_ipq807x_DEVICE_<id>`), which a multi-device build
never sets — they apply to a one-device build like `xiaomi_ax3600` and not to a
group. In a group the profile is whatever the group config says, and a board in
the wrong one gets an image built for the wrong amount of RAM.

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
adds the device list, the memory profiles and any board-specific package
pruning. `prepare-build.sh` concatenates them (the device file wins on a symbol
set in both) and runs `make defconfig`. To change something, edit in a real
OpenWrt checkout and diff back:

```sh
git clone --branch nss-edma-rework https://github.com/JuliusBairaktaris/openwrt-nss-edma openwrt
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

## Enabling offload extras

The image ships the full default offload stack (NAT/PPPoE/VLAN via ECM, wired
bridge offload, same-subnet multicast, NSS SQM, Wi-Fi). A few more offloads are
wired in the source tree but left **off by default** because the reference
network does not use them. Each is enabled by adding its package to
`devices/common/config` and rebuilding:

| Feature | Add | How it offloads |
|---|---|---|
| Routed L3 multicast (IPTV WAN→LAN) | `CONFIG_PACKAGE_igmpproxy=y` (or `smcroute`) | The daemon installs kernel multicast-routing (MFC) entries; ECM (`ECM_MULTICAST_ENABLE`, already on) turns each into a PPE hardware rule. Needs a real upstream multicast source and the receiver subnet on its own netdev (one bridge is a single ipmr VIF). |
| MAP-T / 464XLAT | `CONFIG_PACKAGE_kmod-nat46=y` | nat46 headers and QCA MAP-T exports are staged in the openwrt tree for ECM. |
| VXLAN | `CONFIG_PACKAGE_kmod-vxlan=y` | fdb/age-update offload via kernel patch `0972`. |
| MACVLAN | `CONFIG_PACKAGE_kmod-macvlan=y` | ECM MACVLAN support via kernel patch `0962`. |
| GRE | `CONFIG_PACKAGE_kmod-gre=y` | ECM GRE support. |

Each package brings its own init/userland; `nss-up` does not start them. Not
available on this platform/firmware: IPsec (ESP) offload, TLS/DTLS, CoDel ECN
marking (see the wiki Limitations page). Wi-Fi mesh offload works on an
11.4-firmware build (`NSS_FIRMWARE_VERSION_11_4` + `ATH11K_NSS_MESH_SUPPORT`);
only the default 12.5 firmware blocks it.

> Routed multicast note: `nss-up` carries a **commented-out** start stage for a
> multicast daemon — it is not run in the default image (no IPTV source on the
> reference network). To enable routed multicast in a fork: add the package
> above, ship your own `/etc/config/igmpproxy` for your topology, disable the
> daemon's boot autostart (so it starts only after the WAN is up), and uncomment
> the stage in `nss-up`.

## Custom feeds

Each `src-git <name> <url>` line in `FEEDS` is appended to `feeds.conf` and updated/installed
individually. The corresponding `CONFIG_FEED_<name>` is then set to `n` so you don't bundle every
package from the feed — only what you explicitly enable in `.config` ships.

## Rootfs overlay

Four overlay layers, applied in order (later wins), each optional:

1. `devices/common/files/` — every image
2. `devices/common/files.edma-nss/` — every image, variant-specific
3. `devices/<id>/files/` — one device
4. `devices/<id>/files.edma-nss/` — one device, variant-specific

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
