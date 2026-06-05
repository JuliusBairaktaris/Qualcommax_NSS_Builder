# Qualcommax Builder

### Fork-friendly OpenWrt firmware builder for Qualcomm IPQ807x — NSS-accelerated **and** mainline EDMA variants

[![Build](https://img.shields.io/github/actions/workflow/status/JuliusBairaktaris/Qualcommax_NSS_Builder/build.yml?branch=main&style=flat-square&logo=github&label=Build)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/actions/workflows/build.yml)
[![Lint](https://img.shields.io/github/actions/workflow/status/JuliusBairaktaris/Qualcommax_NSS_Builder/lint.yml?branch=main&style=flat-square&logo=github&label=Lint)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/actions/workflows/lint.yml)
[![License](https://img.shields.io/github/license/JuliusBairaktaris/Qualcommax_NSS_Builder?style=flat-square&label=License)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/JuliusBairaktaris/Qualcommax_NSS_Builder?style=flat-square&label=Last%20Commit)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/commits/main)

A clean, opinionated GitHub Actions template for building OpenWrt firmware for Qualcomm IPQ807x devices. The build is a **matrix over variants** declared in [`builder.yml`](builder.yml): a hardened **NSS-accelerated** image (qosmio's NSS tree) and a fully-mainline **EDMA** image (OpenWrt + [PR #22381](https://github.com/openwrt/openwrt/pull/22381), no proprietary offload). The reference device is the Xiaomi AX3600; adding another is a directory copy.

- **Single fork knob** — every variant, device, and feed lives in [`builder.yml`](builder.yml)
- **Two first-class variants** — NSS and EDMA built from the same shared base config + a small per-variant fragment
- **No caching** — fresh runner every build, predictable output, no cache-poisoning surface
- **Tested release pruning** — "keep last N *per variant*" has unit tests
- **Linted pipeline** — `actionlint`, `shellcheck`, `yamllint` run on every PR
- **Reproducible NSS builds** — pinned `SOURCE_DATE_EPOCH`, fixed locale, no ccache

---

## Variants

| | `nss` | `edma` |
|---|---|---|
| **Upstream** | `qosmio/openwrt-ipq` (NSS fork) | `Ansuel/openwrt` `qca-edma-rework` (PR #22381) |
| **Ethernet** | NSS hardware offload | `qca-edma` driver, CPU-bound |
| **Proprietary blobs** | yes (NSS firmware + kernel patches) | none (all upstreamable) |
| **Throughput** | 2+ Gbps NAT, low CPU | lower (CPU-limited), but real CAKE SQM |
| **QoS** | `sqm-scripts-nss` (`nss-zk.qos`) | `sqm-scripts` (`cake`) **+ QoSmate** (HFSC/CAKE) + SW flow offload |
| **Builds on** | schedule + push (auto, skipped if unchanged) | same — auto-rebuilds when the PR branch moves |
| **Release tag** | `main-nss-<ts>-<run>` | `edma-<ts>-<run>` |

Both share all the hardening, toolchain, and SSH/TLS choices below — they differ only in the data path. See [`docs/VARIANTS.md`](docs/VARIANTS.md) for the full rationale and how to add your own variant.

EDMA builds the PR #22381 branch (`Ansuel/openwrt @ qca-edma-rework`) directly and — like NSS — rebuilds automatically whenever the author pushes (skipped while unchanged). Force one anytime via **Actions → Build → Run workflow → variant: `edma`**.

---

## Quick fork

1. Click **Use this template** → create your repo.
2. Edit [`builder.yml`](builder.yml). The defaults build a working AX3600 image for both variants; change `device:`, `feeds:`, or add a variant to retarget.
3. (Optional) Customize [`devices/<id>/config`](devices/xiaomi_ax3600/config) (+ `config.<variant>`) and the `files*/` overlays.
4. Push to `main`. Both variants build on push and every 2 hours, each skipped automatically when its upstream is unchanged.
5. Releases land on the **Releases** page of your fork.

For a different device, see [`docs/ADD_A_DEVICE.md`](docs/ADD_A_DEVICE.md).

---

## Repo layout

```
.
├── builder.yml                      # the file you fork-edit — defines the variants
├── devices/
│   └── xiaomi_ax3600/
│       ├── config                   # shared base .config
│       ├── config.nss               # NSS fragment (appended to base)
│       ├── config.edma              # EDMA fragment (appended to base)
│       ├── files/                   # overlay shared by both variants
│       ├── files.nss/               # NSS-only overlay (sqm + offload settings)
│       └── files.edma/              # EDMA-only overlay (sqm + offload settings)
├── common/files/                    # overlay shared by all devices and variants
├── patches/                         # *.patch applied to all variants; patches/<id>/ per variant
├── scripts/                         # bash helpers (tested, linted)
│   ├── load-config.sh               # builder.yml -> build matrix (+ variant selection)
│   ├── check-updates.sh             # resolve SHAs, skip unchanged variants
│   ├── prepare-build.sh             # merge PRs, feeds, assemble .config, overlays
│   ├── prune-releases.sh            # keep newest N per release prefix
│   └── tests/
├── docs/
│   ├── VARIANTS.md                  # NSS vs EDMA, and adding a variant
│   ├── ADD_A_DEVICE.md
│   ├── CUSTOMIZE.md
│   └── ARCHITECTURE.md
└── .github/workflows/
    ├── build.yml                    # config -> check-updates -> build (matrix) -> prune
    └── lint.yml                     # actionlint + shellcheck + yamllint + prune tests
```

---

## How the pipeline works

```
config -> check-updates -> build (matrix over variants) -> prune
```

| Job | Purpose |
|---|---|
| `config` | Parses `builder.yml`, selects the variants for this event (scheduled set, or the `workflow_dispatch` choice), emits the build matrix |
| `check-updates` | Resolves each variant's upstream (and NSS) commit; drops variants whose latest release already records that commit (manual runs always build) |
| `build` | For each selected variant: checks out its upstream, merges any PRs, applies overlays, compiles, uploads the artifact, creates a GitHub Release. `fail-fast: false` — one variant breaking doesn't abort the other |
| `prune` | Keeps the newest `release.keep` releases **per variant prefix** (`scripts/prune-releases.sh`) |

Each job has minimal `permissions`. The cron schedule is the only knob outside `builder.yml` (GitHub Actions requires it as a static string).

---

## Reference build: Xiaomi AX3600 (IPQ8071A)

### NSS hardware acceleration (`nss` variant)

The IPQ807x SoC has dedicated Network Subsystem cores. Without NSS, all NAT/bridge/VLAN traffic hits the ARM CPU and tops out around 600-800 Mbps. With NSS enabled:

| Metric | CPU-only stock | NSS offload (`nss`) |
|---|---|---|
| NAT throughput | ~600-800 Mbps | **2+ Gbps** |
| CPU at 1 Gbps | 80-100% | **<15%** |
| SQM + NAT | ~300-500 Mbps | **1+ Gbps** |
| Latency under load | high (bufferbloat) | **low (fq_codel + HW QoS)** |

Enabled NSS modules: `kmod-qca-nss-drv`, `kmod-qca-nss-drv-bridge-mgr`, `kmod-qca-nss-ecm`, `kmod-qca-nss-drv-pppoe`, `kmod-qca-nss-drv-vlan-mgr`, `kmod-qca-mcs`, `sqm-scripts-nss`.

### EDMA mainline build (`edma` variant)

A fully-upstreamable image built directly from [PR #22381](https://github.com/openwrt/openwrt/pull/22381) (Ansuel's `qca-edma`/`qca-ppe`/`qca-uniphy` rework on `Ansuel/openwrt @ qca-edma-rework`). No NSS firmware, no out-of-tree kernel patches. Ethernet is CPU-bound, so NAT throughput is lower than NSS, but you get a clean mainline kernel and full software CAKE/SQM. Ships **[QoSmate](https://github.com/hudra0/qosmate)** (advanced HFSC/CAKE QoS + LuCI app) — EDMA-only, since it shapes on the Linux/tc data path that NSS offload bypasses. Rebuilds automatically when the PR branch is updated (or force it via **Run workflow → variant: `edma`**).

### Security hardening (both variants)

- **OpenSSH** (Dropbear disabled) with post-quantum KEX (ML-KEM 768, sntrup761), AEAD ciphers only, ETM MACs, RSA min 3072
- **Build hardening**: `PKG_ASLR_PIE_ALL`, `PKG_CC_STACKPROTECTOR_ALL`, `PKG_FORTIFY_SOURCE_3`, `PKG_RELRO_FULL`, `USE_SECCOMP`, `PKG_CHECK_FORMAT_SECURITY`
- **Firewall**: WAN input/forward = DROP, HTTPS redirect, BCP38 anti-spoofing
- **OQS provider** loaded into OpenSSL for hybrid post-quantum TLS

### Toolchain

| Component | Setting |
|---|---|
| GCC | 15 + Graphite loops |
| Binutils | 2.45 |
| Linker | Mold |
| LTO | enabled |
| Target flags | `-O2 -pipe -mcpu=cortex-a53+crc+crypto` |
| ccache | **disabled** (no caching policy) |

> Toolchain version pins live in the shared base config. On the mainline EDMA tree, any symbol that doesn't exist there is dropped harmlessly by `make defconfig` (the EDMA image then uses mainline's default toolchain).

### Flashing

Pick the right release: `main-nss-*` for the NSS build, `edma-*` for the EDMA build ([Releases](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/releases)). Grab the `*-sysupgrade.bin` and:

```sh
sysupgrade -n /tmp/openwrt-qualcommax-ipq807x-xiaomi_ax3600-squashfs-sysupgrade.bin
```

Or via LuCI: **System → Backup / Flash Firmware**, upload, uncheck "Keep settings" for a first-time flash. Coming from stock Xiaomi? Install OpenWrt first via the [official guide](https://openwrt.org/toh/xiaomi/ax3600).

---

## Customizing

| What | Where |
|---|---|
| Variants (upstream, feeds, target, prefix) | [`builder.yml`](builder.yml) → `variants` |
| Active device(s) | [`builder.yml`](builder.yml) → `variants[].device` |
| Release retention (per prefix) | [`builder.yml`](builder.yml) → `release.keep` |
| Build cron | [`.github/workflows/build.yml`](.github/workflows/build.yml) → `on.schedule` |
| Shared package selection | [`devices/<id>/config`](devices/xiaomi_ax3600/config) |
| Per-variant packages | [`devices/<id>/config.<variant>`](devices/xiaomi_ax3600/config.nss) |
| Rootfs overlay (shared / per-variant) | `devices/<id>/files/`, `devices/<id>/files.<variant>/` |
| Source patches | [`patches/`](patches) (all) or `patches/<variant>/` |

See [`docs/CUSTOMIZE.md`](docs/CUSTOMIZE.md) and [`docs/VARIANTS.md`](docs/VARIANTS.md) for the long version.

---

## Contributing

Issues and PRs welcome — see [`CONTRIBUTING.md`](CONTRIBUTING.md). Especially valuable:
- A working `devices/<other_ipq807x_device>/` (AX9000, DL-WRX36, etc.)
- Patches that fix upstream regressions
- Doc improvements

---

## Acknowledgements

- **[qosmio](https://github.com/qosmio)** — NSS development and the [openwrt-ipq](https://github.com/qosmio/openwrt-ipq) tree
- **[Ansuel (Christian Marangi)](https://github.com/Ansuel)** — the [EDMA rework](https://github.com/openwrt/openwrt/pull/22381) that makes a non-NSS IPQ807x image possible
- **[rodriguezst](https://github.com/rodriguezst)** — original [ipq807x-openwrt-builder](https://github.com/rodriguezst/ipq807x-openwrt-builder) inspiration
- **OpenWrt community** — the long-running [IPQ807x NSS Build thread](https://forum.openwrt.org/t/ipq807x-nss-build/148529)

---

## License

[GPL-2.0](LICENSE), consistent with OpenWrt.
