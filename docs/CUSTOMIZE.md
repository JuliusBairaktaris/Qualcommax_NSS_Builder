# Customizing the build

All knobs live in **[`builder.yml`](../builder.yml)**, **[`devices/<id>/config`](../devices/xiaomi_ax3600/config)**, and the overlay directories. This page shows what each knob does.

## `builder.yml`

```yaml
upstream:
  repo: qosmio/openwrt-ipq           # OpenWrt source tree
  branch: main-nss

nss_packages:
  repo: qosmio/nss-packages          # NSS packages tree (tracked separately so we can detect package-only updates)
  branch: NSS-12.5-K6.x

device: xiaomi_ax3600                # selects devices/<id>/

feeds:                               # appended to feeds.conf as src-git lines
  - name: qosmio
    url: https://github.com/qosmio/packages-extra
  - name: sqm_nss
    url: https://github.com/JuliusBairaktaris/sqm-scripts-nss

release:
  prefix: main-nss                   # tag = <prefix>-<UTC timestamp>-<run id>
  keep: 2                            # newest N releases retained; older ones deleted
  artifact_retention_days: 7         # GitHub Actions artifact retention (separate from the release)
```

## Device `.config`

Lives at `devices/<id>/config`. It's a normal OpenWrt `.config` — the format produced by `make menuconfig` or `scripts/diffconfig.sh`.

To change something:

```sh
# In a clone of the upstream tree, with this template's config dropped in:
cp devices/xiaomi_ax3600/config openwrt/.config
cd openwrt
make menuconfig
./scripts/diffconfig.sh > ../devices/xiaomi_ax3600/config
```

## Custom feeds

Each entry under `feeds:` becomes one `src-git <name> <url>` line in `feeds.conf` and is updated/installed individually. The corresponding `CONFIG_FEED_<name>` is set to `n` afterwards so you don't accidentally bundle every package from the feed into the image — only the ones you explicitly enable in `.config` ship.

## Source patches

Drop `.patch` files into [`patches/`](../patches/). They're applied to the OpenWrt source in lexicographic order via `git apply`. Standard `git format-patch` output works.

To skip a flaky patch temporarily, rename it to `.patch.disabled`.

## Rootfs overlay

Two overlay directories, applied in this order (later wins):

1. `common/files/` — shared by every device
2. `devices/<id>/files/` — device-specific

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

This template does not use `actions/cache` and explicitly sets `# CONFIG_CCACHE is not set` in the device config. If you fork and want a cached build, you're on your own — but be aware:
- `actions/cache` for OpenWrt is a footgun (toolchain+build-dir is multi-GB and easily corrupts mid-build)
- ccache without persistent storage is a no-op on fresh runners

## Disabling the schedule

If you only want manual builds:

```yaml
on:
  workflow_dispatch:
  push:
    branches: [main]
    paths: [ ... ]
  # remove the schedule: block
```
