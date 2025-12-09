# Qualcommax NSS Builder

**Automated OpenWrt Firmware Builder for Xiaomi AX3600 (IPQ807x)**

![Build Status](https://img.shields.io/github/actions/workflow/status/JuliusBairaktaris/Qualcommax_NSS_Builder/build.yaml?style=flat-square)

This project provides a fully automated workflow to build optimized, hardened, and feature-rich OpenWrt firmware images for the **Xiaomi AX3600**. It leverages the [Qualcommax Nss Build](https://github.com/qosmio/openwrt-ipq) source, integrating custom enhancements for performance and security.

---

## 🚀 Key Features

### ⚡ Performance & NSS Offloading

- **Full NSS Support**: Utilizes the Qualcomm Network Subsystem for hardware acceleration, ensuring maximum throughput with minimal CPU usage.
- **Optimized SQM**: Pre-configured Smart Queue Management using `fq_codel` and `nss-zk.qos`.
  - **Tuned for Speed**: Default settings are optimized for **300+ Mbps FTTH** connections.
  - **Low Latency**: Aggressive targets (3ms) for superior gaming and VoIP performance.

### 🛡️ Security Hardening

- **Hardened SSH**: Implements industry-standard configurations based on [SSH-Audit](https://github.com/jtesta/ssh-audit) and [BSI](https://www.bsi.bund.de/) guidelines.
  - Disables weak ciphers and key exchange algorithms.
  - Enforces strong authentication methods.
- **Firewall & Network Defaults**: Secure baseline settings applied automatically via UCI defaults.

### 🛠️ Automated & Customizable

- **GitHub Actions Workflow**: Builds are triggered automatically on upstream commits or can be dispatched manually.
- **UCI Defaults System**:
  - [`999-QOL_config`](files/etc/uci-defaults/999-QOL_config): General quality-of-life settings for wireless and network.
  - [`999-sqm-settings`](files/etc/uci-defaults/999-sqm-settings): Dedicated SQM optimization script.
- **Custom Packages**: Includes a curated list of useful packages via [`ax3600.config`](ax3600.config).

---

## ⚙️ Configuration Details

### SQM Settings (Smart Queue Management)

The firmware comes with a highly optimized SQM configuration out of the box. The settings are applied via `uci-defaults` on the first boot.

- **Interface**: `wan` (eth1)
- **Script**: `nss-zk.qos` (Hardware accelerated QOS)
- **QDisc**: `fq_codel`
- **Link Layer Adaptation**: None (Optimized for fiber/ethernet)
- **Bandwidth Limits**: Capped at 3000 Mbps (effectively unlimited for most Gigabit connections, acting as a bufferbloat safeguard).

### SSH Configuration

The SSH daemon (`sshd`) is configured to reject legacy and insecure connection attempts. If you are unable to connect with an older client, please update your SSH client to support modern algorithms (e.g., Ed25519, chacha20-poly1305).

---

## 🏗️ Build Process

The build is handled entirely by GitHub Actions:

1.  **Monitor**: Checks for updates in the upstream [qosmio/openwrt-ipq](https://github.com/qosmio/openwrt-ipq) repository.
2.  **Prepare**: Sets up the build environment and dependencies.
3.  **Patch**: Applies custom patches (e.g., NSS load status).
4.  **Configure**: Merges `ax3600.config` and custom files.
5.  **Compile**: Builds the firmware image.
6.  **Release**: Uploads artifacts and creates a GitHub Release.

---

## 🤝 Acknowledgements

- **[qosmio](https://github.com/qosmio)**: for the incredible work on the core NSS development and OpenWrt sources.
- **[rodriguezst](https://github.com/rodriguezst)**: for the [`ipq807x-openwrt-builder`](https://github.com/rodriguezst/ipq807x-openwrt-builder) inspiration.
- **OpenWrt Community**: specifically the [IPQ807x NSS Build thread](https://forum.openwrt.org/t/ipq807x-nss-build/148529).
