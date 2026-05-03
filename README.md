# Qualcommax NSS Builder

### Fork-friendly OpenWrt firmware builder with NSS hardware acceleration

[![Build](https://img.shields.io/github/actions/workflow/status/JuliusBairaktaris/Qualcommax_NSS_Builder/build.yml?branch=main&style=flat-square&logo=github&label=Build)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/actions/workflows/build.yml)
[![Lint](https://img.shields.io/github/actions/workflow/status/JuliusBairaktaris/Qualcommax_NSS_Builder/lint.yml?branch=main&style=flat-square&logo=github&label=Lint)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/actions/workflows/lint.yml)
[![License](https://img.shields.io/github/license/JuliusBairaktaris/Qualcommax_NSS_Builder?style=flat-square&label=License)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/JuliusBairaktaris/Qualcommax_NSS_Builder?style=flat-square&label=Last%20Commit)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/commits/main)

A clean, opinionated GitHub Actions template for building NSS-accelerated OpenWrt firmware for Qualcomm IPQ807x devices. The reference build targets the Xiaomi AX3600, but the template is structured so adding another device is a directory copy and one line in `builder.yml`.

- **Single fork knob** — everything you'd want to change lives in [`builder.yml`](builder.yml)
- **No caching** — fresh runner every build, predictable output, no cache-poisoning surface
- **Tested release pruning** — the "keep last N" logic has unit tests
- **Linted pipeline** — `actionlint`, `shellcheck`, `yamllint` run on every PR
- **Reproducible** — pinned `SOURCE_DATE_EPOCH`, fixed locale, no ccache

---

## Quick fork

1. Click **Use this template** -> create your repo.
2. Edit [`builder.yml`](builder.yml). The defaults already build a working AX3600 image; change `device:`, `feeds:`, etc. to retarget.
3. (Optional) Customize [`devices/<id>/config`](devices/xiaomi_ax3600/config) and [`devices/<id>/files/`](devices/xiaomi_ax3600/files).
4. Push to `main`. The build runs immediately and every 2 hours after.
5. Releases land on the **Releases** page of your fork.

For a different device, see [`docs/ADD_A_DEVICE.md`](docs/ADD_A_DEVICE.md).

---

## Repo layout

```
.
├── builder.yml                      # the file you fork-edit
├── devices/
│   └── xiaomi_ax3600/
│       ├── config                   # OpenWrt .config
│       └── files/                   # rootfs overlay (UCI defaults, sshd_config, ...)
├── common/files/                    # overlay shared by all devices
├── patches/                         # *.patch files applied to the OpenWrt source
├── scripts/                         # bash helpers (tested, linted)
│   ├── load-config.sh
│   ├── prepare-build.sh
│   ├── prune-releases.sh
│   └── tests/
├── docs/
│   ├── ADD_A_DEVICE.md
│   ├── CUSTOMIZE.md
│   └── ARCHITECTURE.md
└── .github/workflows/
    ├── build.yml                    # the build pipeline (config -> check-updates -> build -> prune)
    └── lint.yml                     # actionlint + shellcheck + yamllint + prune tests
```

---

## How the pipeline works

```
config -> check-updates -> build (compile + release) -> prune
```

| Job | Purpose |
|---|---|
| `config` | Parses `builder.yml` and exposes every value as a job output |
| `check-updates` | Polls upstream + NSS repos; skips the build if nothing changed |
| `build` | Installs deps, applies overlays, compiles, uploads artifact, creates GitHub Release |
| `prune` | Runs `scripts/prune-releases.sh` to delete releases beyond `release.keep` |

Each job has minimal `permissions`. The cron schedule is the only knob outside `builder.yml` (GitHub Actions requires it as a static string).

---

## Reference build: Xiaomi AX3600 (IPQ8071A)

The default `builder.yml` builds a hardened, NSS-accelerated firmware for the **Xiaomi AX3600**.

### NSS hardware acceleration

The IPQ807x SoC has dedicated Network Subsystem cores for packet processing. Without NSS, all NAT/bridge/VLAN traffic hits the ARM CPU and tops out around 600-800 Mbps. With NSS enabled (this build):

| Metric | CPU-only stock | NSS offload (this build) |
|---|---|---|
| NAT throughput | ~600-800 Mbps | **2+ Gbps** |
| CPU at 1 Gbps | 80-100% | **<15%** |
| SQM + NAT | ~300-500 Mbps | **1+ Gbps** |
| Latency under load | high (bufferbloat) | **low (fq_codel + HW QoS)** |

Enabled NSS modules: `kmod-qca-nss-drv`, `kmod-qca-nss-drv-bridge-mgr`, `kmod-qca-nss-ecm`, `kmod-qca-nss-drv-pppoe`, `kmod-qca-nss-drv-vlan-mgr`, `kmod-qca-mcs`, `luci-mod-status-nss`, `sqm-scripts-nss`.

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

### Flashing

Latest release: [Releases page](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/releases/latest). Grab the `*-sysupgrade.bin` and:

```sh
sysupgrade -n /tmp/openwrt-qualcommax-ipq807x-xiaomi_ax3600-squashfs-sysupgrade.bin
```

Or via LuCI: **System -> Backup / Flash Firmware**, upload, uncheck "Keep settings" for first-time flash. Coming from stock Xiaomi? Install OpenWrt first via the [official guide](https://openwrt.org/toh/xiaomi/ax3600).

---

## Customizing

| What | Where |
|---|---|
| Upstream repo / branch | [`builder.yml`](builder.yml) -> `upstream` |
| NSS packages | [`builder.yml`](builder.yml) -> `nss_packages` |
| Active device | [`builder.yml`](builder.yml) -> `device` |
| Custom feeds | [`builder.yml`](builder.yml) -> `feeds` |
| Release retention | [`builder.yml`](builder.yml) -> `release.keep` |
| Build cron | [`.github/workflows/build.yml`](.github/workflows/build.yml) -> `on.schedule` |
| Kernel/package selection | [`devices/<id>/config`](devices/xiaomi_ax3600/config) |
| Rootfs overlay (per-device) | [`devices/<id>/files/`](devices/xiaomi_ax3600/files) |
| Rootfs overlay (shared) | [`common/files/`](common/files) |
| Source patches | [`patches/`](patches) |

See [`docs/CUSTOMIZE.md`](docs/CUSTOMIZE.md) for the long version.

---

## Contributing

Issues and PRs welcome — see [`CONTRIBUTING.md`](CONTRIBUTING.md). Especially valuable:
- A working `devices/<other_ipq807x_device>/` (AX9000, DL-WRX36, etc.)
- Patches that fix upstream regressions
- Doc improvements

---

## Acknowledgements

- **[qosmio](https://github.com/qosmio)** — NSS development and the [openwrt-ipq](https://github.com/qosmio/openwrt-ipq) tree
- **[rodriguezst](https://github.com/rodriguezst)** — original [ipq807x-openwrt-builder](https://github.com/rodriguezst/ipq807x-openwrt-builder) inspiration
- **OpenWrt community** — the long-running [IPQ807x NSS Build thread](https://forum.openwrt.org/t/ipq807x-nss-build/148529)

---

## License

[GPL-2.0](LICENSE), consistent with OpenWrt.
