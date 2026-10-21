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

Find your router on **[ppenss.github.io](https://ppenss.github.io/)**. It
links the sysupgrade image of each board, builds custom images with
packages added or left out, lists the kernel modules of each release and
explains updates. The images are also on the
[releases](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/releases)
page.

There is no factory image. Install stock OpenWrt from its
[device page](https://openwrt.org/toh/start) first, then flash the
sysupgrade image in LuCI (System → Backup / Flash Firmware). After a fresh
install, Wi-Fi is off and has no key.

Images update themselves with `ppe-update` (System → Firmware update),
keeping settings and added packages. Kernel modules install with
`apk add kmod-<name>` from the release's own feed; the official OpenWrt
kmods do not load. Coming from an `edma-nss` image, follow
[Migrating from edma-nss](https://github.com/JuliusBairaktaris/openwrt-ppe-nss/wiki/Migrating-from-edma-nss).

The Xiaomi AX3600 is the test board. The other boards are built but not
tested by the maintainer, who has no IPQ60xx hardware. Reports are welcome
in the [forum thread](https://forum.openwrt.org/t/qualcommax-nss-build/148529).

## What ships

| Area | Contents |
|---|---|
| Routing, NAT | PPE through the fw4 flowtable: IPv4/IPv6, NAT, PPPoE, 802.1Q VLAN |
| Bridge, multicast | PPE through switchdev, with IGMP/MLD snooping; kernel multicast routing enabled |
| SQM | PPE shaper through tc offload: `hw_ppe.qos` in `sqm-scripts`, `luci-app-sqm` |
| QoS classes | `qca-ppe-qos`, `luci-app-qca-ppe-qos`, `dcb`, `tc`, `ethtool-full`, `devlink` |
| Wi-Fi | `kmod-nss-wifi-drv`: the ath11k data path on the NSS cores, on by default |
| Base | OpenSSH instead of Dropbear, OpenSSL, LuCI over HTTPS, BCP38, `htop`, `iperf3`, `curl` |
| Kernel modules | USB storage, TUN and WireGuard built in; ramoops crash logs archived to `/root/pstore` |
| Toolchain | GCC 15, Binutils 2.46, mold, LTO, PIE/SSP/FORTIFY_SOURCE=3/RELRO |

First-boot defaults (applied once, kept across upgrades): WAN zone input
set to DROP, BCP38 on `wan`, LuCI redirected to HTTPS, and the router
serving NTP to the LAN (DHCP option 42).

Routed multicast (IPTV) needs a daemon such as `igmpproxy`, which is not
bundled: add it in the image picker, or see
[docs/CUSTOMIZE.md](docs/CUSTOMIZE.md#routed-multicast).

## Build it yourself

Fork this repo and run the Build workflow, or build locally:

```sh
git clone --branch ppe-nss https://github.com/JuliusBairaktaris/openwrt-ppe-nss openwrt
git clone https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder builder
cd openwrt
cp feeds.conf.default feeds.conf
echo "src-git nss https://github.com/JuliusBairaktaris/nss-packages.git;ppe-nss" >> feeds.conf
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
