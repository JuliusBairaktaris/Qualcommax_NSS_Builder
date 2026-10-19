# Customizing the build

A build is set by three things:

- the `env:` block and the matrix in
  [`.github/workflows/build.yml`](../.github/workflows/build.yml);
- the shared config [`devices/common/config`](../devices/common/config)
  plus one config per board group;
- the overlay files and patches under `devices/` and `patches/`.

## Build parameters

```yaml
env:
  UPSTREAM_REPO: JuliusBairaktaris/openwrt-ppe-nss   # OpenWrt source tree
  UPSTREAM_REF: ppe-nss                               # branch, tag or SHA
  NSS_REPO: JuliusBairaktaris/nss-packages            # nss-firmware feed
  NSS_REF: edma-nss
  VARIANT: ppe-nss                                    # selects files.<variant> and patches/*/<variant>
  RELEASE_PREFIX: ppe-nss                             # tag = <prefix>-<timestamp>-<run id>
  KEEP: "2"                                           # newest releases kept per prefix
  FEEDS: |
    src-git nss https://github.com/JuliusBairaktaris/nss-packages.git;edma-nss
    src-git luci https://github.com/JuliusBairaktaris/luci.git;luci-app-ppe-qos
```

Each `FEEDS` line is added to `feeds.conf`. A line with the name of an
existing feed replaces it, which is how the luci fork with
`luci-app-qca-ppe-qos` stands in for the default luci feed. A new feed is not
bundled whole: only the packages selected in the config are built.

## Groups

The `build` job builds every group:

```yaml
    strategy:
      matrix:
        device: [xiaomi_ax3600, ipq807x-1g, ipq807x-512m, ipq807x-256m, ipq60xx-1g, ipq60xx-512m]
```

A group is one `devices/<group>/` directory. Boards share a group when they
share a subtarget and a RAM size, because the ath11k memory profile is
fixed at build time for the whole image. The subtarget is set in each
group's config, so IPQ807x and IPQ60xx groups build side by side.

To add a board, add one line to the config of its group:

```
CONFIG_TARGET_DEVICE_qualcommax_<subtarget>_DEVICE_<board>=y
```

`CONFIG_TARGET_PER_DEVICE_ROOTFS=y` keeps each image to the packages of
its own board.

## The config

`scripts/prepare-build.sh` concatenates `devices/common/config`,
`devices/<group>/config` and the `CONFIG_FRAGMENT` file if set, in that order; the last
file wins on a symbol set twice. Then it runs `make defconfig` and checks
that every symbol set to `y` is still set. Kconfig drops a symbol whose
dependencies are not met without a word, so a missing one fails the build.

To change the config, edit it in a real checkout and diff it back:

```sh
git clone --branch ppe-nss https://github.com/JuliusBairaktaris/openwrt-ppe-nss openwrt
cat devices/common/config devices/xiaomi_ax3600/config > openwrt/.config
cd openwrt && make menuconfig
./scripts/diffconfig.sh > /tmp/delta.config
```

Then split the delta over `devices/common/config` and the group config.
Do not turn off a board's hardware in the shared config: `DEVICE_PACKAGES`
pulls in each board's ath10k firmware, USB and 10G PHY support, and the
boards that have that hardware need it.

## Routed multicast

Multicast inside a bridge is offloaded through switchdev with no extra
package. Routed multicast (IPTV from the WAN) needs a daemon that fills the
kernel multicast routing table, which the images do not bundle. Add
`CONFIG_PACKAGE_igmpproxy=y` (or `smcroute`) to `devices/common/config` and
ship your own `/etc/config/igmpproxy` as an overlay file. The kernel
multicast routing options are already set.

## Overlay files

Four layers are copied into the image, later ones winning:

1. `devices/common/files/`: every image
2. `devices/common/files.<variant>/`: every image of the variant
3. `devices/<group>/files/`: one group
4. `devices/<group>/files.<variant>/`: one group, one variant

Paths are kept.
`etc/uci-defaults/*` scripts run once on first boot and after each
sysupgrade; write them so that they do not overwrite a setting the user
changed. `etc/rc.local` runs on every boot.

## Patches

- `patches/feeds/<variant>/<feed>/*.patch` apply to a feed after
  `feeds update`. The `ppe-nss` one points `sqm-scripts` at the fork that
  carries `hw_ppe.qos`.
- `patches/tree/<variant>/*.patch` apply to the OpenWrt tree. They carry
  fixes not yet in the branch being built. A patch that is already applied
  is skipped; one that does not apply fails the build.

## Schedule and triggers

```yaml
on:
  schedule:
    - cron: "0 */2 * * *"
```

A scheduled run builds only when the `ppe-nss` or `edma-nss` commit
differs from the one the latest release records. A push to `devices/`,
`scripts/` or the workflow, and a manual run, always build. Remove the
`schedule:` block for manual builds only.

## Caches

Two GitHub Actions caches speed up builds:

- `dl-*` holds the verified source downloads, so a stalled mirror does not
  fail a build. Delete the `dl-` entries to start over.
- `ccache-<variant>-<toolchain hash>-*` holds the compiler cache. The key
  covers every toolchain input, so a toolchain change starts with an empty
  cache.
