# Qualcommax Builder

### Fork-friendly OpenWrt firmware builder for Qualcomm IPQ807x — NSS offload on the upstream EDMA drivers

[![Build](https://img.shields.io/github/actions/workflow/status/JuliusBairaktaris/Qualcommax_NSS_Builder/build.yml?branch=main&style=flat-square&logo=github&label=Build)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/actions/workflows/build.yml)
[![Lint](https://img.shields.io/github/actions/workflow/status/JuliusBairaktaris/Qualcommax_NSS_Builder/lint.yml?branch=main&style=flat-square&logo=github&label=Lint)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/actions/workflows/lint.yml)
[![License](https://img.shields.io/github/license/JuliusBairaktaris/Qualcommax_NSS_Builder?style=flat-square&label=License)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/JuliusBairaktaris/Qualcommax_NSS_Builder?style=flat-square&label=Last%20Commit)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/commits/main)

A clean, opinionated GitHub Actions template for building OpenWrt firmware for Qualcomm IPQ807x devices. The build is a **matrix over variants** declared in [`builder.yml`](builder.yml); the default (and currently only) variant is **`edma-nss`**: Qualcomm NSS hardware offloading running on **OpenWrt main's upstream `qca-edma`/`qca-ppe` ethernet drivers** ([PR #22381](https://github.com/openwrt/openwrt/pull/22381)) — built from [openwrt-nss-edma](https://github.com/JuliusBairaktaris/openwrt-nss-edma) and [nss-packages](https://github.com/JuliusBairaktaris/nss-packages). The reference device is the Xiaomi AX3600; adding another is a directory copy.

- **Single fork knob** — every variant, device, and feed lives in [`builder.yml`](builder.yml)
- **No caching** — fresh runner every build, predictable output, no cache-poisoning surface
- **Tested release pruning** — "keep last N *per variant*" has unit tests
- **Linted pipeline** — `actionlint`, `shellcheck`, `yamllint` run on every PR
- **Reproducible builds** — pinned `SOURCE_DATE_EPOCH`, fixed locale, no ccache

---

## The `edma-nss` variant

| | `edma-nss` |
|---|---|
| **OpenWrt tree** | [`JuliusBairaktaris/openwrt-nss-edma`](https://github.com/JuliusBairaktaris/openwrt-nss-edma) @ `nss-edma-rework` (OpenWrt main + PR #22381 + the NSS integration series) |
| **NSS packages** | [`JuliusBairaktaris/nss-packages`](https://github.com/JuliusBairaktaris/nss-packages) @ `edma-nss` (drv, ECM, qdisc/igs/pppoe clients, firmware 12.5, `sqm-scripts-nss`) |
| **Ethernet** | the upstream `qca-edma` DSA driver, with the firmware data plane attached at runtime |
| **Offload** | ECM NAT/PPPoE, NSS SQM (`nss-edma.qos`), ath11k NSS Wi-Fi offload (wifili) |
| **Builds on** | schedule + push (auto, skipped while both source trees are unchanged) |
| **Release tag** | `edma-nss-<ts>-<run>` |

This is, to our knowledge, the first NSS stack that keeps the upstream ethernet drivers instead of the vendor `qca-nss-dp`/`qca-ssdk` pairing. Architecture, runtime model, measured results and limitations are documented in the **[openwrt-nss-edma wiki](https://github.com/JuliusBairaktaris/openwrt-nss-edma/wiki)**.

**Runtime model:** the image boots on the plain host stack (Wi-Fi in host mode — loading the NSS modules is inert by design). `/usr/sbin/nss-up`, invoked from `rc.local`, arms the NSS data plane, boots the firmware, moves the radios onto the wifili data path and starts ECM + SQM. A reboot always returns to the stock host-only stack — that is the universal recovery path. Remove the `nss-up` line from `/etc/rc.local` to stay on the host stack permanently.

The historical `nss` (qosmio tree) and `edma` (PR #22381 without NSS) variants were retired when `edma-nss` superseded both — one image now provides the upstream drivers *and* the offload. They remain available in the git history if you want to resurrect one as a custom variant.

---

## Quick fork

1. Click **Use this template** → create your repo.
2. Edit [`builder.yml`](builder.yml). The defaults build a working AX3600 image; change `device:`, `feeds:`, or add a variant to retarget.
3. (Optional) Customize [`devices/<id>/config`](devices/xiaomi_ax3600/config) (+ `config.<variant>`) and the `files*/` overlays.
4. Push to `main`. The variant builds on push and every 2 hours, skipped automatically when its upstreams are unchanged.
5. Releases land on the **Releases** page of your fork.

For a different device, see [`docs/ADD_A_DEVICE.md`](docs/ADD_A_DEVICE.md).

---

## Repo layout

```
.
├── builder.yml                      # the file you fork-edit — defines the variants
├── devices/
│   └── xiaomi_ax3600/
│       ├── config                   # shared base .config (hardening, toolchain, QoL)
│       ├── config.edma-nss          # variant fragment (NSS + Wi-Fi offload packages)
│       ├── files/                   # overlay shared by all variants
│       └── files.edma-nss/          # variant overlay (nss-up, sqm + offload settings)
├── common/files/                    # overlay shared by all devices and variants
├── patches/                         # *.patch applied to all variants; patches/<id>/ per variant
├── scripts/                         # bash helpers (tested, linted)
│   ├── load-config.sh               # builder.yml -> build matrix (+ variant selection)
│   ├── check-updates.sh             # resolve SHAs, skip unchanged variants
│   ├── prepare-build.sh             # merge PRs, feeds, assemble .config, overlays
│   ├── prune-releases.sh            # keep newest N per release prefix
│   └── tests/
├── docs/
│   ├── VARIANTS.md                  # variant model, and adding a variant
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
| `check-updates` | Resolves each variant's upstream (and NSS) commit; on scheduled ticks it drops variants whose latest release already records that commit (push + manual runs always build) |
| `build` | For each selected variant: checks out its upstream, merges any PRs, applies overlays, compiles, uploads the artifact, creates a GitHub Release. `fail-fast: false` — one variant breaking doesn't abort the others |
| `prune` | Keeps the newest `release.keep` releases **per variant prefix** (`scripts/prune-releases.sh`) |

Each job has minimal `permissions`. The cron schedule is the only knob outside `builder.yml` (GitHub Actions requires it as a static string).

---

## Reference build: Xiaomi AX3600 (IPQ8071A)

### NSS hardware acceleration on upstream drivers

The IPQ807x SoC has dedicated Network Subsystem cores. Without NSS, all NAT/bridge/VLAN traffic hits the ARM CPU. Measured on this stack (AX3600, NSS.FW.12.5-210, kernel 6.12; details in the [wiki](https://github.com/JuliusBairaktaris/openwrt-nss-edma/wiki)):

| Metric | Host path | NSS offload (`edma-nss`) |
|---|---|---|
| 311 Mbit/s PPPoE NAT | ~42% of one core (softirq) | **~99.7% CPU idle** |
| SQM at 285 Mbit ingress | CPU-bound | **258 Mbit goodput, ~99% idle** |
| RTT under shaped load | high (bufferbloat) | **16 ms avg vs 20 idle — flat** |
| Wi-Fi data path | mac80211/ath11k on CPU | **wifili on the NSS cores** |

Enabled NSS modules: `kmod-qca-nss-drv` (+ the `kmod-qca-ppe-nss` glue), `kmod-qca-nss-ecm`, `kmod-qca-nss-drv-pppoe`, `kmod-qca-nss-drv-qdisc`/`-igs`, `sqm-scripts-nss` (`nss-edma.qos`), ath11k NSS Wi-Fi offload (`CONFIG_ATH11K_NSS_SUPPORT`).

### Security hardening

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

> Toolchain version pins live in the shared base config.

### Flashing

Grab the `*-sysupgrade.bin` from the newest `edma-nss-*` release ([Releases](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/releases)) and:

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
| Per-variant packages | [`devices/<id>/config.<variant>`](devices/xiaomi_ax3600/config.edma-nss) |
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

- **[Ansuel (Christian Marangi)](https://github.com/Ansuel)** — the [EDMA rework](https://github.com/openwrt/openwrt/pull/22381) this stack builds on
- **[qosmio](https://github.com/qosmio)** — NSS development, the [openwrt-ipq](https://github.com/qosmio/openwrt-ipq) tree, and the Wi-Fi offload patch lineage
- **[rodriguezst](https://github.com/rodriguezst)** — original [ipq807x-openwrt-builder](https://github.com/rodriguezst/ipq807x-openwrt-builder) inspiration
- **OpenWrt community** — the long-running [IPQ807x NSS Build thread](https://forum.openwrt.org/t/ipq807x-nss-build/148529)

---

## License

[GPL-2.0](LICENSE), consistent with OpenWrt.
