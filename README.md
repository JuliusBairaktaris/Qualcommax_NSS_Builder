# Qualcommax NSS Builder

### Prebuilt OpenWrt firmware with Qualcomm NSS hardware offload for IPQ807x and IPQ60xx (IPQ6018) routers

[![Build](https://img.shields.io/github/actions/workflow/status/JuliusBairaktaris/Qualcommax_NSS_Builder/build.yml?branch=main&style=flat-square&logo=github&label=Build)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/actions/workflows/build.yml)
[![Lint](https://img.shields.io/github/actions/workflow/status/JuliusBairaktaris/Qualcommax_NSS_Builder/lint.yml?branch=main&style=flat-square&logo=github&label=Lint)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/actions/workflows/lint.yml)
[![License](https://img.shields.io/github/license/JuliusBairaktaris/Qualcommax_NSS_Builder?style=flat-square&label=License)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/JuliusBairaktaris/Qualcommax_NSS_Builder?style=flat-square&label=Last%20Commit)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/commits/main)
[![Downloads](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2FJuliusBairaktaris%2FQualcommax_NSS_Builder%2Fstats%2Fdownloads.json&style=flat-square)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/releases)

OpenWrt sysupgrade images with hardware offload for 41 IPQ807x and 24
IPQ60xx boards of the `qualcommax` target, built by GitHub Actions from the
`ppe-nss` branch of
[openwrt-ppe-nss](https://github.com/JuliusBairaktaris/openwrt-ppe-nss).

The wired traffic (routing, NAT, PPPoE, VLAN, bridging, multicast snooping
and SQM) runs in the PPE, the packet engine in the SoC's switch, through
OpenWrt's upstream `qca_edma`/`qca_ppe` drivers and the kernel's own
offload interfaces. The Wi-Fi data path of the SoC radios runs on the NSS
cores through `nss-wifi-drv`. There is no ECM, no NSS qdisc and no vendor
NSS host driver. Only the NSS firmware comes from
[nss-packages](https://github.com/JuliusBairaktaris/nss-packages).

How the offload works, how to check it and what is not covered is in the
[openwrt-ppe-nss wiki](https://github.com/JuliusBairaktaris/openwrt-ppe-nss/wiki).

## Install

Pick your router in the [image picker](https://ppenss.github.io/),
or download `openwrt-qualcommax-<subtarget>-<board>-squashfs-sysupgrade.bin`
from a [release](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/releases),
and flash it in LuCI (System → Backup / Flash Firmware) or over ssh:

```sh
sysupgrade -n /tmp/openwrt-qualcommax-ipq807x-xiaomi_ax3600-squashfs-sysupgrade.bin
```

There is no factory image. The router must already run OpenWrt; install
stock OpenWrt first from its [device page](https://openwrt.org/toh/start).

| Release | Use it for |
|---|---|
| `ppe-nss-*` | The default. NSS firmware 12.5 (`NSS.FW.12.5-210-HK.R` on IPQ807x, `NSS.FW.12.5-210-CP.R` on IPQ60xx) and 11.4.0.5, the last line that accepts an 802.11s mesh interface. The images boot 12.5; `uci set nss-wifi.general.firmware=11.4; uci commit nss-wifi; reboot` switches to 11.4. |
| `ppe-nss-mesh-*` | Earlier mesh builds on 11.4. No longer built: the `ppe-nss` images carry both lines. |
| `ppe-offload-test` | One prerelease, replaced in place. OpenWrt main with the PPE offload from the `ppe-flow-offload` branch and no NSS. For testing only. |
| `edma-nss-*` | The archived vendor NSS stack. No longer built. |

Each release names the source commit it was built from and carries a
`config-<group>.buildinfo` with the full configuration. The two newest
releases of each kind are kept.

After a fresh install, Wi-Fi is off and has no key. Connect by cable, set
an SSID and key under Network → Wireless, and enable the radios.

<details>
<summary>Boards built: 41 IPQ807x, 24 IPQ60xx</summary>

Boards are built in groups by subtarget and RAM, because the ath11k memory
profile is fixed at build time for the whole image.

| Group | RAM | Boards |
|---|---|---|
| `xiaomi_ax3600` | 512 MB | Xiaomi AX3600 (adds its wireless defaults and an SQM template) |
| `ipq807x-1g` | 1 GB+ | Aliyun AP8220, Arcadyan AW1000, Asus RT-AX89X, Buffalo WXR-5950AX12, Dynalink DL-WRX36, Edgecore EAP102, Linksys HomeWRK, Linksys MX4200 v2, Linksys MX4300, Linksys MX5300, Linksys MX8500, Netgear RAX120v2, Netgear RBR750, Netgear RBR850, Netgear RBS750, Netgear RBS850, Netgear SXR80, Netgear SXS80, Netgear WAX620, Netgear WAX630, prpl Haze, QNAP 301w, Spectrum SAX1V1K, TCL LINKHUB HH500V, TP-Link Deco X80-5G, TP-Link EAP620 HD v1, TP-Link EAP660 HD v1, Xiaomi AX9000, Yuncore AX880, Zbtlink ZBT-Z800AX, Zyxel NBG7815, Zyxel NWA110AX, Zyxel NWA210AX |
| `ipq807x-512m` | 512 MB | CMCC RM2-6, Compex WPQ873, Edimax CAX1800, Linksys MX4200 v1, Redmi AX6, ZTE MF269 |
| `ipq807x-256m` | 256 MB | Netgear WAX218 |
| `ipq60xx-1g` | 1 GB+ | Cambium Networks XE3-4, JDCloud RE-CS-02, JDCloud RE-CS-07, Link NN6000 v1, Link NN6000 v2, TP-Link EAP620 HD v2, TP-Link EAP620 HD v3, TP-Link EAP623-Outdoor HD v1 |
| `ipq60xx-512m` | 512 MB | 8devices Mango DVK, Alfa Network AP120C-AX, GL.iNet GL-AX1800 (Flint), GL.iNet GL-AXT1800 (Slate AX), JDCloud RE-SS-01, Linksys MR7350, Linksys MR7500, Netgear RBR350, Netgear RBS350, Netgear WAX214, Netgear WAX610, Netgear WAX610Y, Qihoo 360V6, TP-Link EAP610-Outdoor, TP-Link EAP625-Outdoor HD v1, Yuncore FAP650 |

The Xiaomi AX3600 is the test board. The other boards are built but not
tested by the maintainer, who has no IPQ60xx hardware. Reports are welcome
in the [forum thread](https://forum.openwrt.org/t/qualcommax-nss-build/148529).
The MikroTik Chateau 5G R17 ax is not built because its device tree has no
NSS node.

</details>

## Offload on and off

Wired offload is the fw4 flowtable with hardware offload, turned on at
first boot (Network → Firewall → Hardware flow offloading).
`grep -c HW_OFFLOAD /proc/net/nf_conntrack` counts the connections in the
PPE.

The NSS Wi-Fi offload is on by default. Turn it off with:

```sh
uci set nss-wifi.general.offload='0'; uci commit nss-wifi; reboot
```

While the offload starts, the service keeps a marker in
`/etc/nss-wifi.pending` and removes it two minutes later. A boot that hangs
leaves the marker, and the next boot stays on the host Wi-Fi path until it
is deleted. `logread -e nss-wifi` shows the bring-up.

## Kernel modules

Each image is set up to install kernel modules built with its own kernel:

```sh
apk update && apk add kmod-<name>
```

The feed belongs to the release the image came from and is removed with it.
After a sysupgrade the image points at its new feed. The image picker lists
the modules of each release.

## Custom images

The [image picker](https://ppenss.github.io/)
builds an image with packages added or left out and an optional first-boot
script. The request opens as an issue here; the `Custom image` workflow
builds it from the release's ImageBuilder and posts the download on the
issue. Custom downloads are deleted after seven days. Packages that the
release did not build come from the OpenWrt snapshot feeds.

## Updates

`ppe-update` moves an image to the newest release of this repository,
keeping the settings and installing the packages added on top of the image
again after the reboot:

```sh
ppe-update check     # is there a newer release?
ppe-update update    # download, verify and flash it
```

In LuCI it is System → Firmware update, which also turns on the automatic
update: once a day it installs a release that has been out for a day.

```sh
uci set ppe-update.main.auto='1'; uci commit ppe-update; /etc/init.d/ppe-update reload
```

## Coming from edma-nss

Upgrade with a normal sysupgrade; settings may be kept. Nothing is migrated
automatically; the [migration page](https://github.com/JuliusBairaktaris/openwrt-ppe-nss/wiki/Migrating-from-edma-nss)
has every step. In short:

- Turn hardware flow offloading on in Network → Firewall. The edma-nss
  images set it to off, and the first-boot default does not override a
  kept setting.
- The `nss` and `nssqos` configs are no longer read.
- Set the SQM script to `hw_ppe.qos` in LuCI.
- `nssqos` DSCP rules are not carried over. Set up queue classifiers under
  Network → PPE QoS.

## What ships

| Area | Contents |
|---|---|
| Routing, NAT | PPE through the fw4 flowtable: IPv4/IPv6, NAT, PPPoE, 802.1Q VLAN |
| Bridge, multicast | PPE through switchdev, with IGMP/MLD snooping; kernel multicast routing enabled |
| SQM | PPE shaper through tc offload: `hw_ppe.qos` in `sqm-scripts`, `luci-app-sqm` |
| QoS classes | `ppe-qos`, `luci-app-ppe-qos`, `dcb`, `tc`, `ethtool-full`, `devlink` |
| Wi-Fi | `kmod-nss-wifi-drv`: the ath11k data path on the NSS cores, on by default |
| Base | OpenSSH instead of Dropbear, OpenSSL, LuCI over HTTPS, BCP38, `htop`, `iperf3`, `curl` |
| Kernel modules | USB storage, TUN and WireGuard built in; ramoops crash logs archived to `/root/pstore` |
| Toolchain | GCC 15, Binutils 2.46, mold, LTO, PIE/SSP/FORTIFY_SOURCE=3/RELRO |

First-boot defaults (applied once, kept across upgrades): WAN zone input
set to DROP, BCP38 on `wan`, LuCI redirected to HTTPS, and the router
serving NTP to the LAN (DHCP option 42).

Kernel modules from the official OpenWrt feeds do not load on these images,
because they use their own kernel. Build what you need into the image.
Routed multicast (IPTV) needs a daemon such as `igmpproxy`, which is not
bundled; [docs/CUSTOMIZE.md](docs/CUSTOMIZE.md#routed-multicast) shows how
to add it.

## Build it yourself

Fork this repo and run the Build workflow, or build locally:

```sh
git clone --branch ppe-nss https://github.com/JuliusBairaktaris/openwrt-ppe-nss openwrt
git clone https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder builder
cd openwrt
cp feeds.conf.default feeds.conf
echo "src-git nss https://github.com/JuliusBairaktaris/nss-packages.git;edma-nss" >> feeds.conf
sed -i 's|^src-git luci .*|src-git luci https://github.com/JuliusBairaktaris/luci.git;luci-app-ppe-qos|' feeds.conf
./scripts/feeds update -a && ./scripts/feeds install -a
patch -d feeds/packages -p1 < ../builder/patches/feeds/ppe-nss/packages/0001-*.patch   # hw_ppe.qos
cat ../builder/devices/common/config ../builder/devices/xiaomi_ax3600/config > .config   # or any devices/<group>
make defconfig && make -j"$(nproc)"
```

`scripts/prepare-build.sh` does all of the above in CI and also copies the
overlay files from `devices/*/files*` into the image.

> [!IMPORTANT]
> `ppe-nss` is rebased often, so `git pull` does not update it. Use:
>
> ```sh
> git fetch origin && git reset --hard origin/ppe-nss
> ./scripts/feeds update -a && ./scripts/feeds install -a
> make defconfig
> ```

[docs/CUSTOMIZE.md](docs/CUSTOMIZE.md) covers the build options and
overlays. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) describes the CI
pipeline.

## Contributing

Issues and PRs are welcome, see [CONTRIBUTING.md](CONTRIBUTING.md). Bugs in
the firmware itself belong in the
[openwrt-ppe-nss issues](https://github.com/JuliusBairaktaris/openwrt-ppe-nss/issues);
the wiki's [Reporting Bugs](https://github.com/JuliusBairaktaris/openwrt-ppe-nss/wiki/Reporting-Bugs)
page lists what to include.

## Acknowledgements

- [Christian Marangi (Ansuel)](https://github.com/Ansuel) for the upstream
  EDMA and PPE drivers.
- [Robert Marko (robimarko)](https://github.com/robimarko) for maintaining the
  OpenWrt qualcommax target.
- [qosmio](https://github.com/qosmio) for NSS development, the
  [openwrt-ipq](https://github.com/qosmio/openwrt-ipq) tree and the NSS
  firmware packaging.
- [rodriguezst](https://github.com/rodriguezst) for the original
  [ipq807x-openwrt-builder](https://github.com/rodriguezst/ipq807x-openwrt-builder).
- The OpenWrt community in the
  [NSS build thread](https://forum.openwrt.org/t/qualcommax-nss-build/148529).

## Support

This is an unpaid single-maintainer project. Donations go toward IPQ60xx and
IPQ50xx test hardware.

- [GitHub Sponsors](https://github.com/sponsors/JuliusBairaktaris)
- [PayPal](https://paypal.me/JuliusBairaktaris)

## License

[GPL-2.0](LICENSE), as OpenWrt.
