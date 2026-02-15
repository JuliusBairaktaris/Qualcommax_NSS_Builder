# Qualcommax NSS Builder

### Automated OpenWrt Firmware with NSS Hardware Acceleration for Xiaomi AX3600 (IPQ807x)

[![Build Status](https://img.shields.io/github/actions/workflow/status/JuliusBairaktaris/Qualcommax_NSS_Builder/build.yaml?branch=main&style=flat-square&logo=github&label=Build)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/actions/workflows/build.yaml)
[![License](https://img.shields.io/github/license/JuliusBairaktaris/Qualcommax_NSS_Builder?style=flat-square&label=License)](LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/JuliusBairaktaris/Qualcommax_NSS_Builder?style=flat-square&logo=github&label=Stars)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/stargazers)
[![Last Commit](https://img.shields.io/github/last-commit/JuliusBairaktaris/Qualcommax_NSS_Builder?style=flat-square&label=Last%20Commit)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/commits/main)
[![Downloads](https://img.shields.io/github/downloads/JuliusBairaktaris/Qualcommax_NSS_Builder/total?style=flat-square&logo=github&label=Downloads)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/releases/latest)

Pre-built, hardened OpenWrt firmware images for the **Xiaomi AX3600** with full **Qualcomm NSS (Network Subsystem) hardware offloading** — delivering **2-5x network throughput** compared to stock CPU-based packet processing. Builds run automatically via GitHub Actions against the latest [qosmio/openwrt-ipq](https://github.com/qosmio/openwrt-ipq) sources. Just download and flash.

---

## Why NSS?

The Qualcomm IPQ807x SoC contains dedicated **Network Subsystem (NSS)** cores designed exclusively for packet processing. Enabling NSS offloading moves traffic handling off the main CPU and onto these specialized cores, dramatically increasing throughput and reducing latency.

| Metric | CPU-only (stock OpenWrt) | NSS Offloading (this firmware) |
|---|---|---|
| NAT Throughput | ~600-800 Mbps | **2+ Gbps** |
| CPU Usage at 1 Gbps | 80-100% | **<15%** |
| SQM + NAT | ~300-500 Mbps | **1+ Gbps** |
| Latency under load | High (bufferbloat) | **Low (fq_codel + HW QoS)** |

> NSS offloading is the single biggest performance upgrade you can make to an IPQ807x router. This firmware enables it out of the box.

---

## Key Features

### Performance

- **Full NSS hardware offloading** — NAT, bridge, PPPoE, VLAN, and ECM all accelerated
- **Hardware-accelerated SQM** — `nss-zk.qos` script with `fq_codel` for bufferbloat-free gigabit
- **TCP BBR congestion control** — Google's BBR for optimal throughput on WAN links
- **Wi-Fi 6 (802.11ax)** — HE160 on 5 GHz, HE40 on 2.4 GHz, with 802.11k/v/r roaming
- **Aggressive compiler optimizations** — GCC 15, LTO, Mold linker, Cortex-A53 tuning

### Security

- **Post-quantum SSH** — ML-KEM 768 + sntrup761 key exchange (OpenSSH, replaces Dropbear)
- **Hardened SSH config** — Based on [SSH-Audit](https://github.com/jtesta/ssh-audit) and [BSI](https://www.bsi.bund.de/) guidelines
- **Build-level hardening** — ASLR/PIE, Stack Protector, FORTIFY_SOURCE 3, Full RELRO, SECCOMP
- **Secure firewall defaults** — WAN input/forward set to DROP, HTTPS redirect enabled
- **BCP38 anti-spoofing** — Ingress filtering to prevent source address spoofing

### Automation

- **Automated builds** — GitHub Actions checks upstream every 2 hours for new commits
- **Ready-to-flash releases** — Sysupgrade images published automatically
- **Reproducible builds** — Pinned toolchain, fixed SOURCE_DATE_EPOCH
- **UCI defaults** — Network, wireless, SQM, and firewall configured out of the box

---

## Supported Devices

| Device | SoC | Status | Config |
|---|---|---|---|
| **Xiaomi AX3600** | Qualcomm IPQ8071A | Actively supported | [`ax3600.config`](ax3600.config) |

> Other IPQ807x devices (AX9000, Dynalink DL-WRX36, etc.) can be added by contributing a config file.

---

## Quick Start

### Download

Grab the latest sysupgrade image from the [Releases page](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/releases/latest).

### Flash via LuCI (Web UI)

1. Navigate to **System > Backup / Flash Firmware**
2. Upload the `*-sysupgrade.bin` file
3. Uncheck "Keep settings" for a clean install (recommended on first flash)
4. Flash and wait for reboot (~2-3 minutes)

### Flash via CLI

```bash
sysupgrade -n /tmp/openwrt-qualcommax-ipq807x-xiaomi_ax3600-squashfs-sysupgrade.bin
```

> **Note**: If you're coming from stock Xiaomi firmware, you need to install OpenWrt first. See the [OpenWrt AX3600 installation guide](https://openwrt.org/toh/xiaomi/ax3600).

---

## What's Inside

### Performance & NSS Offloading

NSS offloading is fully enabled across all supported subsystems:

| NSS Module | Function |
|---|---|
| `kmod-qca-nss-drv` | Core NSS driver |
| `kmod-qca-nss-drv-bridge-mgr` | Bridge acceleration |
| `kmod-qca-nss-ecm` | Enhanced Connection Manager |
| `kmod-qca-nss-drv-pppoe` | PPPoE offloading |
| `kmod-qca-nss-drv-vlan-mgr` | VLAN acceleration |
| `kmod-qca-mcs` | Multicast snooping |
| `luci-mod-status-nss` | NSS status in LuCI |
| `sqm-scripts-nss` | Hardware-accelerated SQM ([JuliusBairaktaris/sqm-scripts-nss](https://github.com/JuliusBairaktaris/sqm-scripts-nss)) |

The SQM configuration targets low-latency use cases (gaming, VoIP) with 4ms queue targets and hardware QoS via the `nss-zk.qos` script. This firmware uses the [JuliusBairaktaris/sqm-scripts-nss](https://github.com/JuliusBairaktaris/sqm-scripts-nss) implementation for improved hardware-accelerated QoS.

### Security Hardening

**SSH** is served by OpenSSH (not Dropbear) with a hardened configuration:

- **Key Exchange**: ML-KEM 768 (post-quantum), sntrup761, Curve25519, ECDH, DH Group 18/16
- **Ciphers**: ChaCha20-Poly1305, AES-256-GCM, AES-256-CTR
- **MACs**: Encrypt-then-MAC only (hmac-sha2-512-etm, hmac-sha2-256-etm, umac-128-etm)
- **Minimum RSA key size**: 3072 bits

**Build hardening** flags applied to all compiled packages:

| Flag | Protection |
|---|---|
| `PKG_ASLR_PIE_ALL` | Address space layout randomization |
| `PKG_CC_STACKPROTECTOR_ALL` | Stack buffer overflow detection |
| `PKG_FORTIFY_SOURCE_3` | Buffer overflow compile-time checks |
| `PKG_RELRO_FULL` | Read-only relocations (GOT hardening) |
| `USE_SECCOMP` | System call filtering |
| `PKG_CHECK_FORMAT_SECURITY` | Format string vulnerability detection |

### Compiler & Toolchain

| Component | Version / Setting |
|---|---|
| GCC | 15 with Graphite loop optimizations |
| Binutils | 2.45 |
| Linker | Mold (parallel, faster than ld/gold) |
| LTO | Enabled (link-time optimization) |
| Target flags | `-O2 -pipe -mcpu=cortex-a53+crc+crypto` |
| zlib | Speed-optimized |
| zstd | `-O3` optimized |
| ccache | Enabled for faster rebuilds |

### Included Packages

| Category | Packages |
|---|---|
| Web UI | LuCI with OpenSSL, Firewall app, SQM app |
| SSH | OpenSSH server + SFTP |
| Networking | curl, iperf3, TCP BBR, BCP38 |
| Wi-Fi | wpad-openssl (WPA3 capable), Wi-Fi 6 |
| Monitoring | htop, NSS status module |

---

## Automated Build Pipeline

The [GitHub Actions workflow](.github/workflows/build.yaml) handles everything:

```
Check upstream (every 2h) -> Detect new commits -> Build firmware -> Publish release
```

1. **Monitor** — Polls [qosmio/openwrt-ipq](https://github.com/qosmio/openwrt-ipq) and [nss-packages](https://github.com/qosmio/nss-packages) for new commits
2. **Prepare** — Installs build dependencies, applies patches, updates feeds
3. **Configure** — Merges [`ax3600.config`](ax3600.config) with custom files and UCI defaults
4. **Compile** — Full firmware build with optimized toolchain
5. **Release** — Uploads sysupgrade images as a GitHub Release
6. **Cleanup** — Retains only the 2 most recent releases

Builds can also be triggered manually via `workflow_dispatch`.

---

## FAQ

### What is NSS and why does it matter for OpenWrt?

NSS (Network Subsystem) is a set of dedicated hardware accelerator cores in Qualcomm IPQ807x SoCs. Without NSS, all packet processing happens on the main ARM CPU, limiting throughput to ~600-800 Mbps. With NSS enabled, packet processing is offloaded to the dedicated cores, pushing throughput past 2 Gbps while keeping CPU usage under 15%.

### Is this firmware compatible with my Xiaomi AX3600?

Yes. This firmware is built specifically for the Xiaomi AX3600 (codename `xiaomi_ax3600`, SoC `IPQ8071A`). It is **not** compatible with other Xiaomi routers like the AX1800 or AX6000 without modifications.

### Can I use SQM (bufferbloat control) with NSS?

Yes. This firmware includes hardware-accelerated SQM via the [JuliusBairaktaris/sqm-scripts-nss](https://github.com/JuliusBairaktaris/sqm-scripts-nss) implementation, which provides the `nss-zk.qos` script. You get bufferbloat control at gigabit speeds with minimal CPU overhead.

### Why OpenSSH instead of Dropbear?

Dropbear does not support post-quantum key exchange algorithms (ML-KEM, sntrup761) or modern hardening features like RSA minimum key size enforcement. OpenSSH provides a significantly stronger security baseline.

### How do I update to a newer build?

Download the latest `*-sysupgrade.bin` from the [Releases page](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/releases/latest) and flash it via LuCI or CLI. Settings are preserved during sysupgrade unless you use the `-n` flag.

### Why are builds triggered every 2 hours?

The workflow checks for new commits in the upstream repositories every 2 hours. If no new commits are found, no build is triggered — so releases only appear when there are actual changes.

### Can I add my own packages to the build?

Fork this repository, edit [`ax3600.config`](ax3600.config) to add your packages, and push. GitHub Actions will build your custom firmware automatically.

---

## Contributing

Contributions are welcome. You can help by:

- Adding support for other IPQ807x devices (submit a config file)
- Reporting build failures or firmware issues
- Suggesting package additions or configuration improvements
- Improving documentation

If this project saved you time or helps you get the most out of your router, consider giving it a star — it helps others find it.

---

## Acknowledgements

- **[qosmio](https://github.com/qosmio)** — Core NSS development and the [openwrt-ipq](https://github.com/qosmio/openwrt-ipq) sources that make this possible
- **[rodriguezst](https://github.com/rodriguezst)** — Inspiration from [ipq807x-openwrt-builder](https://github.com/rodriguezst/ipq807x-openwrt-builder)
- **OpenWrt Community** — Especially the [IPQ807x NSS Build thread](https://forum.openwrt.org/t/ipq807x-nss-build/148529) (4000+ posts and counting)

---

## License

This project is licensed under the [GPL-2.0](LICENSE) license, consistent with OpenWrt.
