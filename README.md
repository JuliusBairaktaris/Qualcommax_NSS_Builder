# Qualcommax NSS Builder

### Prebuilt OpenWrt firmware with Qualcomm NSS hardware offload for IPQ807x and IPQ60xx (IPQ6018) routers

[![Build](https://img.shields.io/github/actions/workflow/status/JuliusBairaktaris/Qualcommax_NSS_Builder/build.yml?branch=main&style=flat-square&logo=github&label=Build)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/actions/workflows/build.yml)
[![Lint](https://img.shields.io/github/actions/workflow/status/JuliusBairaktaris/Qualcommax_NSS_Builder/lint.yml?branch=main&style=flat-square&logo=github&label=Lint)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/actions/workflows/lint.yml)
[![License](https://img.shields.io/github/license/JuliusBairaktaris/Qualcommax_NSS_Builder?style=flat-square&label=License)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/JuliusBairaktaris/Qualcommax_NSS_Builder?style=flat-square&label=Last%20Commit)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/commits/main)
[![Downloads](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2FJuliusBairaktaris%2FQualcommax_NSS_Builder%2Fstats%2Fdownloads.json&style=flat-square)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/releases)

OpenWrt sysupgrade images with PPE and NSS hardware offload (NAT, PPPoE,
VLAN, SQM, bridge, multicast and Wi-Fi) for every IPQ807x and IPQ60xx board in
the `qualcommax` target, including the Xiaomi AX3600, Redmi AX6, Linksys
MX4300 and MR7350, GL.iNet GL-AX1800 Flint and Dynalink DL-WRX36. The images
run OpenWrt main's upstream `qca_edma`/`qca_ppe` drivers and use only
in-kernel offload interfaces: no ECM, no NSS qdiscs and no vendor NSS host
driver. They are built by GitHub Actions from the `ppe-nss` branch of
[openwrt-ppe-nss](https://github.com/JuliusBairaktaris/openwrt-ppe-nss);
only the NSS firmware comes from
[nss-packages](https://github.com/JuliusBairaktaris/nss-packages).

> [!NOTE]
> The vendor NSS stack (qca-nss-drv, ECM, NSS qdiscs) is no longer built.
> Its last `edma-nss-*` releases stay on the releases page, and its build
> setup is the [`archive/edma-nss-final`](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/tree/archive/edma-nss-final)
> tag. Moving from `edma-nss` to `ppe-nss` is a normal sysupgrade; see
> [Coming from edma-nss](#coming-from-edma-nss).

Background and design are in the
[wiki](https://github.com/JuliusBairaktaris/openwrt-ppe-nss/wiki), starting
with [PPE and NSS Wi-Fi Offload](https://github.com/JuliusBairaktaris/openwrt-ppe-nss/wiki/PPE-and-NSS-Wi-Fi-Offload).

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
| `ppe-nss-*` | The default. NSS firmware 12.5 (`NSS.FW.12.5-210-HK.R` on IPQ807x, `NSS.FW.12.5-210-CP.R` on IPQ60xx). |
| `ppe-nss-mesh-*` | 802.11s mesh. Same images on NSS firmware 11.4.0.5, the last line that supports mesh. |
| `ppe-offload-test` | One prerelease, replaced in place. Stock OpenWrt with PPE flowtable offload and no NSS, for testing only. |
| `edma-nss-*` | Archived vendor NSS stack. No longer built or updated. |

Wi-Fi ships disabled with no key. Connect by cable, set an SSID and key under
Network → Wireless, and enable the radios.

<details>
<summary>Devices built: 41 IPQ807x, 24 IPQ60xx</summary>

Boards are grouped by subtarget and RAM.

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

The wired offload is the fw4 flowtable, switched on at first boot (Network →
Firewall → hardware flow offloading). `grep -c HW_OFFLOAD /proc/net/nf_conntrack`
counts the flows in the PPE.

The NSS Wi-Fi offload is on by default. Turn it off with:

```sh
uci set nss-wifi.general.offload='0'; uci commit nss-wifi; reboot
```

The flag is cleared while the offload starts and set again two minutes after
the firmware has taken the data plane, so a boot that hangs falls back to the
host Wi-Fi path on the next boot. `logread -e nss-wifi` shows the bring-up.

## Coming from edma-nss

Upgrade with a normal sysupgrade; settings may be kept. The `nss` and
`nssqos` configs are no longer read. On the Xiaomi AX3600 image the `sqm.wan`
section is moved from `nss-edma.qos` to `hw_ppe.qos`; on other boards set the
SQM script to `hw_ppe.qos` in LuCI. `nssqos` DSCP rules are not carried over;
set up queue classifiers under Network → PPE QoS.

## What ships

| Area | Packages |
|---|---|
| Routing, NAT | PPE through the fw4 flowtable: IPv4/IPv6, NAT, PPPoE, 802.1Q VLAN |
| Bridge, multicast | PPE through switchdev, with multicast snooping |
| SQM | PPE shaper through tc qdisc offload: `hw_ppe.qos` in `sqm-scripts`, `luci-app-sqm` |
| QoS classes | `ppe-qos`, `luci-app-ppe-qos` (queue classifiers) |
| Wi-Fi | `kmod-nss-wifi-drv`: the ath11k data path on the NSS cores, on by default |
| Base | OpenSSH instead of Dropbear, OpenSSL, LuCI over HTTPS, BCP38, `htop`, `iperf3`, `curl` |
| Toolchain | GCC 15, Binutils 2.46, mold, LTO, PIE/SSP/FORTIFY_SOURCE=3/RELRO |

Routed multicast (IPTV) needs a multicast routing daemon, which is not
bundled. [docs/CUSTOMIZE.md](docs/CUSTOMIZE.md) shows how to add one.

## Build it yourself

Fork this repo and edit the `env:` block of
[build.yml](.github/workflows/build.yml), or build locally:

```sh
git clone --branch ppe-nss https://github.com/JuliusBairaktaris/openwrt-ppe-nss openwrt
cd openwrt
cp feeds.conf.default feeds.conf
echo "src-git nss https://github.com/JuliusBairaktaris/nss-packages.git;edma-nss" >> feeds.conf
sed -i 's|^src-git luci .*|src-git luci https://github.com/JuliusBairaktaris/luci.git;luci-app-ppe-qos|' feeds.conf
./scripts/feeds update -a && ./scripts/feeds install -a
B=../Qualcommax_NSS_Builder
patch -d feeds/packages -p1 < "$B"/patches/feeds/ppe-nss/packages/0001-*.patch   # hw_ppe.qos
cat "$B/devices/common/config" "$B/devices/xiaomi_ax3600/config" > .config   # or any devices/<group>
make defconfig && make -j"$(nproc)"
```

> [!IMPORTANT]
> `ppe-nss` is rebased regularly, so `git pull` does not update it. Use:
>
> ```sh
> git fetch origin && git reset --hard origin/ppe-nss
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
