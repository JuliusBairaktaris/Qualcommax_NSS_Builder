# Qualcommax NSS Builder

### Prebuilt OpenWrt firmware with Qualcomm NSS hardware offload for IPQ807x and IPQ60xx (IPQ6018) routers

[![Build](https://img.shields.io/github/actions/workflow/status/JuliusBairaktaris/Qualcommax_NSS_Builder/build.yml?branch=main&style=flat-square&logo=github&label=Build)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/actions/workflows/build.yml)
[![Lint](https://img.shields.io/github/actions/workflow/status/JuliusBairaktaris/Qualcommax_NSS_Builder/lint.yml?branch=main&style=flat-square&logo=github&label=Lint)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/actions/workflows/lint.yml)
[![License](https://img.shields.io/github/license/JuliusBairaktaris/Qualcommax_NSS_Builder?style=flat-square&label=License)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/JuliusBairaktaris/Qualcommax_NSS_Builder?style=flat-square&label=Last%20Commit)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/commits/main)
[![Downloads](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2FJuliusBairaktaris%2FQualcommax_NSS_Builder%2Fstats%2Fdownloads.json&style=flat-square)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/releases)

OpenWrt sysupgrade images with NSS hardware offload (NAT, PPPoE, SQM, bridge
and Wi-Fi) for every IPQ807x and IPQ60xx board in the `qualcommax` target,
including the Xiaomi AX3600, Redmi AX6, Linksys MX4300 and MR7350, GL.iNet
GL-AX1800 Flint and Dynalink DL-WRX36. The offload runs on OpenWrt main's
upstream `qca_edma`/`qca_ppe` ethernet drivers instead of the vendor
`qca-nss-dp`/`qca-ssdk` stack. Images are built by GitHub Actions from
[openwrt-nss-edma](https://github.com/JuliusBairaktaris/openwrt-nss-edma) and
[nss-packages](https://github.com/JuliusBairaktaris/nss-packages).

Background and design are in the
[wiki](https://github.com/JuliusBairaktaris/openwrt-nss-edma/wiki), starting
with [NSS Offload Explained](https://github.com/JuliusBairaktaris/openwrt-nss-edma/wiki/NSS-Offload-Explained).

## Install

Download `...-<your device>-squashfs-sysupgrade.bin` from a
[release](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/releases)
and flash it from LuCI (System → Backup / Flash Firmware) or over ssh:

```sh
sysupgrade -n /tmp/openwrt-qualcommax-ipq807x-xiaomi_ax3600-squashfs-sysupgrade.bin
```

There is no factory image. The device must already run OpenWrt; install stock
OpenWrt first using its [device page](https://openwrt.org/toh/start).

| Release | Use it for |
|---|---|
| `edma-nss-*` | The default. NSS firmware 12.5 (`NSS.FW.12.5-210-HK.R` on IPQ807x, `NSS.FW.12.5-210-CP.R` on IPQ60xx). |
| `edma-nss-mesh-*` | 802.11s mesh offload. Same images on NSS firmware 11.4.0.5, the last line that supports mesh. |
| `ppe-offload-test` | One prerelease, replaced in place. Stock OpenWrt with PPE flowtable offload and no NSS, for testing only. |

Wi-Fi ships disabled with no key. Connect by cable, set an SSID and key under
Network → Wireless, and enable the radios.

<details>
<summary>Devices built: 41 IPQ807x, 24 IPQ60xx</summary>

Boards are grouped by subtarget and ath11k memory profile, which are both
image-wide build options.

| Group | RAM | Devices |
|---|---|---|
| `xiaomi_ax3600` | 512 MB | Xiaomi AX3600 (adds its wireless defaults and an SQM template) |
| `ipq807x-1g` | 1 GB+ | Aliyun AP8220, Arcadyan AW1000, Asus RT-AX89X, Buffalo WXR-5950AX12, Dynalink DL-WRX36, Edgecore EAP102, Linksys HomeWRK, Linksys MX4200 v2, Linksys MX4300, Linksys MX5300, Linksys MX8500, Netgear RAX120v2, Netgear RBR750, Netgear RBR850, Netgear RBS750, Netgear RBS850, Netgear SXR80, Netgear SXS80, Netgear WAX620, Netgear WAX630, prpl Haze, QNAP 301w, Spectrum SAX1V1K, TCL LINKHUB HH500V, TP-Link Deco X80-5G, TP-Link EAP620 HD v1, TP-Link EAP660 HD v1, Xiaomi AX9000, Yuncore AX880, Zbtlink ZBT-Z800AX, Zyxel NBG7815, Zyxel NWA110AX, Zyxel NWA210AX |
| `ipq807x-512m` | 512 MB | CMCC RM2-6, Compex WPQ873, Edimax CAX1800, Linksys MX4200 v1, Redmi AX6, ZTE MF269 |
| `ipq807x-256m` | 256 MB | Netgear WAX218 |
| `ipq60xx-1g` | 1 GB+ | Cambium Networks XE3-4, JDCloud RE-CS-02, JDCloud RE-CS-07, Link NN6000 v1, Link NN6000 v2, TP-Link EAP620 HD v2, TP-Link EAP620 HD v3, TP-Link EAP623-Outdoor HD v1 |
| `ipq60xx-512m` | 512 MB | 8devices Mango DVK, Alfa Network AP120C-AX, GL.iNet GL-AX1800 (Flint), GL.iNet GL-AXT1800 (Slate AX), JDCloud RE-SS-01, Linksys MR7350, Linksys MR7500, Netgear RBR350, Netgear RBS350, Netgear WAX214, Netgear WAX610, Netgear WAX610Y, Qihoo 360V6, TP-Link EAP610-Outdoor, TP-Link EAP625-Outdoor HD v1, Yuncore FAP650 |

The Xiaomi AX3600 is the test device. The IPQ60xx images are new and lightly
tested, and the maintainer has no IPQ60xx hardware; reports are welcome in the
[forum thread](https://forum.openwrt.org/t/qualcommax-nss-build/148529).
The MikroTik Chateau 5G R17 ax is not built because its device tree has no NSS
node.

</details>

## Status and recovery

`nss-status` over ssh, or LuCI Status → NSS Offload, shows the offload state.
Boot messages are in `logread -e nss`. To run the plain host stack instead:

```sh
uci set nss.general.enabled='0'; uci commit nss; reboot
```

The setting survives sysupgrade.

## What ships

| Area | Packages |
|---|---|
| NSS core | `kmod-qca-nss-drv`, firmware memory profile matched to RAM |
| NAT offload | ECM (IPv4 NAT, IPv6 routing), PPPoE |
| Bridge, multicast | `kmod-qca-nss-drv-bridge-mgr`, `kmod-qca-nss-ecm` |
| SQM | NSS qdiscs with `sqm-scripts-nss` and `luci-app-sqm`, shipped disabled; set your line rates and enable it |
| QoS marking | `nssqos`, `luci-app-nssqos` (DSCP rules for offloaded flows) |
| Wi-Fi | ath11k NSS offload (wifili) |
| Diagnostics | `nss-status`, `luci-app-nss`, `nssinfo` |
| Base | OpenSSH instead of Dropbear, OpenSSL, LuCI over HTTPS, BCP38, `htop`, `iperf3`, `curl` |
| Toolchain | GCC 15, Binutils 2.46, mold, LTO, PIE/SSP/FORTIFY_SOURCE=3/RELRO |

Routed multicast (IPTV), MAP-T, VXLAN, MACVLAN and GRE build but are off by
default. [docs/CUSTOMIZE.md](docs/CUSTOMIZE.md) shows how to enable them.

## Measured results

Xiaomi AX3600, NSS firmware 12.5, kernel 6.18:

| Metric | Host path | NSS offload |
|---|---|---|
| 311 Mbit/s PPPoE NAT | ~42 % of one core (softirq) | ~99.7 % CPU idle |
| SQM at 285 Mbit/s ingress | CPU-bound | 258 Mbit/s goodput, ~99 % idle |
| RTT under shaped load | bufferbloat | 16 ms avg vs 20 ms idle |
| Wi-Fi data path | mac80211/ath11k on the CPU | wifili on the NSS cores |

## Build it yourself

Fork this repo and edit the `env:` block of
[build.yml](.github/workflows/build.yml), or build locally:

```sh
git clone --branch nss-edma-rework https://github.com/JuliusBairaktaris/openwrt-nss-edma openwrt
cd openwrt
cp feeds.conf.default feeds.conf
echo "src-git nss https://github.com/JuliusBairaktaris/nss-packages.git;edma-nss" >> feeds.conf
./scripts/feeds update -a && ./scripts/feeds install -a
B=../Qualcommax_NSS_Builder/devices
cat "$B/common/config" "$B/xiaomi_ax3600/config" > .config   # or any devices/<group>
make defconfig && make -j"$(nproc)"
```

> [!IMPORTANT]
> `nss-edma-rework` and the `edma-nss` feed are rebased regularly, so
> `git pull` and `./scripts/feeds update` do not update them. Use:
>
> ```sh
> git fetch origin && git reset --hard origin/nss-edma-rework
> rm -rf feeds/nss package/feeds/nss
> ./scripts/feeds update -a && ./scripts/feeds install -a
> make defconfig
> ```

[docs/CUSTOMIZE.md](docs/CUSTOMIZE.md) covers build options and overlays.
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) describes the CI pipeline.

## Contributing

Issues and PRs are welcome, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Acknowledgements

- [Christian Marangi (Ansuel)](https://github.com/Ansuel) for the upstream
  EDMA and PPE drivers.
- [Robert Marko (robimarko)](https://github.com/robimarko) for maintaining the
  OpenWrt qualcommax target.
- [qosmio](https://github.com/qosmio) for NSS development, the
  [openwrt-ipq](https://github.com/qosmio/openwrt-ipq) tree and the Wi-Fi
  offload patches
- [rodriguezst](https://github.com/rodriguezst) for the original
  [ipq807x-openwrt-builder](https://github.com/rodriguezst/ipq807x-openwrt-builder)
- The OpenWrt community in the
  [NSS build thread](https://forum.openwrt.org/t/qualcommax-nss-build/148529)

## Support

This is an unpaid single-maintainer project. Donations go toward IPQ60xx and
IPQ50xx test hardware.

- [GitHub Sponsors](https://github.com/sponsors/JuliusBairaktaris)
- [PayPal](https://paypal.me/JuliusBairaktaris)

## License

[GPL-2.0](LICENSE), as OpenWrt.
