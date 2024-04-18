# Qualcommax NSS Builder

This project automates OpenWRT builds for the Xiaomi AX3600, focusing on comprehensive NSS support with a minimalistic approach to additional packages. It is based on the `qualcommax-6.1-nss-wifi` branch from [qosmio/openwrt-ipq](https://github.com/qosmio/openwrt-ipq/tree/qualcommax-6.1-nss-wifi) and draws inspiration from [rodriguezst/ipq807x-openwrt-builder](https://github.com/rodriguezst/ipq807x-openwrt-builder).

## Features

The build features:

- **Full NSS (Network Subsystem) support**
- **NSS info patch** for the Luci status page by @qosmio
- **Security and Network Management Tools**:
  - `luci-app-banip`
  - `luci-ssl-openssl`
  - `iperf3`
  - `htop`
- **Hardened OpenSSH configuration** using recommendations from [ssh-audit](https://github.com/jtesta/ssh-audit)
- `wpad-openssl` (Full).
- **Build with** `CONFIG_TARGET_OPTIMIZATION="-O3 -pipe -mcpu=cortex-a53+crc+crypto"; CONFIG_USE_LTO=y; CONFIG_USE_MOLD=y; CONFIG_ZLIB_OPTIMIZE_SPEED=y; CONFIG_PACKAGE_luci-ssl-openssl=y` for higher Performance.
- Default congestion algorithm is `bbr`

## Recommended Configuration

- Packet Steering: Disabled.
- Software / Hardware flow offloading: Disabled.
- Set your specific country code for WIFI.

## Known Issues

- None

## Contributing

Contributions are highly appreciated! If you have suggestions for additional packages, essential features that are missing, or improvements to the existing setup, please feel free to submit a pull request or open an issue. Your input helps make Qualcommax_NSS_Builder even better for everyone.
