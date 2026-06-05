# Customizing the build

All knobs live in **[`builder.yml`](../builder.yml)**, **[`devices/<id>/config`](../devices/xiaomi_ax3600/config)**
(+ the `config.<variant>` fragments), and the overlay directories. This page shows what each
knob does. For the NSS-vs-EDMA story and how to add a variant, see [`VARIANTS.md`](VARIANTS.md).

## `builder.yml`

```yaml
release:
  keep: 2                            # newest releases retained *per variant prefix*
  artifact_retention_days: 7         # Actions artifact retention (separate from the release)

variants:
  - id: nss                          # also names the config fragment: config.nss
    scheduled: true                  # built on schedule + push (false = manual only)
    upstream:
      repo: qosmio/openwrt-ipq       # OpenWrt source tree
      ref: main-nss                  # branch, tag, or 40-char SHA
    nss_packages:                    # optional — only variants that need the NSS feed
      repo: qosmio/nss-packages
      ref: NSS-12.5-K6.x
    target: qualcommax/ipq807x       # bin/targets/<target>/ (also the artifact path)
    device: xiaomi_ax3600            # selects devices/<id>/
    feeds:                           # appended to feeds.conf as `src-git <name> <url>`
      - name: qosmio
        url: https://github.com/qosmio/packages-extra
      - name: sqm_nss
        url: https://github.com/JuliusBairaktaris/sqm-scripts-nss
    release:
      prefix: main-nss               # tag = <prefix>-<UTC timestamp>-<run id>

  - id: edma
    scheduled: false                 # manual workflow_dispatch only
    upstream:
      repo: Ansuel/openwrt           # PR #22381 author's fork
      ref: qca-edma-rework           # the PR branch, built directly
    target: qualcommax/ipq807x
    device: xiaomi_ax3600
    feeds: []
    release:
      prefix: edma
```

Which variants build depends on the trigger:
- **schedule / push** → variants with `scheduled: true`.
- **Run workflow** (`workflow_dispatch`) → the `variant:` input (`all`, or a specific id).

## Device `.config` — base + fragment

Each variant's `.config` is assembled by concatenating a shared base with a variant fragment,
then running `make defconfig`:

```
devices/<id>/config            # shared base (target, toolchain, hardening, SSH, packages)
devices/<id>/config.<variant>  # variant fragment (e.g. NSS modules, or EDMA + cake)
```

To change something, edit in a real OpenWrt checkout and diff back into the right file:

```sh
# Shared change -> goes in the base:
cat devices/xiaomi_ax3600/config devices/xiaomi_ax3600/config.nss > openwrt/.config
cd openwrt && make menuconfig
./scripts/diffconfig.sh > /tmp/full.config
# then move new shared lines into devices/<id>/config and NSS-only lines into config.nss
```

Symbols that don't exist on a given upstream are dropped silently by `make defconfig` — that's
how the EDMA fragment can share the base even though the NSS fork and mainline differ slightly.

## Custom feeds

Each entry under a variant's `feeds:` becomes one `src-git <name> <url>` line in `feeds.conf`,
updated/installed individually. The corresponding `CONFIG_FEED_<name>` is then set to `n` so you
don't bundle every package from the feed — only what you explicitly enable in `.config` ships.

## Merging OpenWrt PRs

A variant can list `merge_prs: [<n>, ...]`. Each PR is `git fetch`ed from the upstream repo and
3-way merged onto `ref` at build time (kept uncommitted). `edma` instead builds the PR branch
directly (see [`VARIANTS.md`](VARIANTS.md) for why), but the mechanism is available for any variant.

## Source patches

Drop `.patch` files into [`patches/`](../patches/) (applied to every variant) or
`patches/<variant>/` (that variant only). Applied in lexicographic order via `git apply` after any
`merge_prs`. Standard `git format-patch` output works. To skip one temporarily, rename it
`.patch.disabled`.

## Rootfs overlay

Three overlay layers, applied in order (later wins):

1. `common/files/` — shared by every device and variant
2. `devices/<id>/files/` — device-specific, both variants
3. `devices/<id>/files.<variant>/` — device + variant specific

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

This template does not use `actions/cache` and explicitly sets `# CONFIG_CCACHE is not set` in the
base config. ccache without persistent storage is a no-op on fresh runners, and `actions/cache` for
OpenWrt's multi-GB build dir is a footgun (easily corrupts mid-build).

## Disabling the schedule

If you only want manual builds, remove the `schedule:` block from `build.yml` (keep
`workflow_dispatch` and `push`). Or set every variant to `scheduled: false`.
