# Qualcommax NSS Builder

### OpenWrt image builder for the Xiaomi AX3600 — NSS hardware offload on the upstream EDMA drivers

[![Build](https://img.shields.io/github/actions/workflow/status/JuliusBairaktaris/Qualcommax_NSS_Builder/build.yml?branch=main&style=flat-square&logo=github&label=Build)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/actions/workflows/build.yml)
[![Lint](https://img.shields.io/github/actions/workflow/status/JuliusBairaktaris/Qualcommax_NSS_Builder/lint.yml?branch=main&style=flat-square&logo=github&label=Lint)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/actions/workflows/lint.yml)
[![License](https://img.shields.io/github/license/JuliusBairaktaris/Qualcommax_NSS_Builder?style=flat-square&label=License)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/JuliusBairaktaris/Qualcommax_NSS_Builder?style=flat-square&label=Last%20Commit)](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/commits/main)

A GitHub Actions pipeline that builds one OpenWrt image for the **Xiaomi
AX3600**: Qualcomm NSS hardware offload running on OpenWrt main's **upstream
`qca_edma` / `qca_ppe` ethernet drivers**
([PR #22381](https://github.com/openwrt/openwrt/pull/22381)) — not the vendor
`qca-nss-dp` / `qca-ssdk` stack every other NSS build uses. Built from
[openwrt-nss-edma](https://github.com/JuliusBairaktaris/openwrt-nss-edma) and
[nss-packages](https://github.com/JuliusBairaktaris/nss-packages).

New to NSS offload? The wiki page
**[NSS Offload Explained](https://github.com/JuliusBairaktaris/openwrt-nss-edma/wiki/NSS-Offload-Explained)**
covers the concept from the ground up. Architecture, runtime model and measured
results are in the
**[full wiki](https://github.com/JuliusBairaktaris/openwrt-nss-edma/wiki)**.

---

## Use it

Grab the `*-sysupgrade.bin` from the newest `edma-nss-*`
[release](https://github.com/JuliusBairaktaris/Qualcommax_NSS_Builder/releases)
and flash it:

```sh
sysupgrade -n /tmp/openwrt-qualcommax-ipq807x-xiaomi_ax3600-squashfs-sysupgrade.bin
```

Or via LuCI: **System → Backup / Flash Firmware**, upload, uncheck "Keep
settings" for a first-time flash. Coming from stock Xiaomi firmware? Install
OpenWrt first via the [official guide](https://openwrt.org/toh/xiaomi/ax3600).

**Runtime model:** the image boots as a normal OpenWrt system on the plain host
stack (Wi-Fi in host mode; the NSS modules are loaded but inert). The `nss`
service (`/etc/init.d/nss`, runs `/usr/sbin/nss-up`) then arms the NSS data
plane, boots the firmware, moves the radios onto the wifili path and starts
ECM + SQM; its output lands in the system log (`logread -e nss`). **Every boot
starts on the stock host-only stack** before the service arms NSS, so a reboot is
always a safe way back — the universal recovery path.
To stay on the host stack permanently:
`uci set nss.general.enabled='0'; uci commit nss` (survives sysupgrade).

Check plane health any time with `nss-status` over ssh, or in LuCI under
**Status → NSS Offload**.

---

## What ships by default

The `edma-nss` image enables the full offload stack plus a hardened, batteries-
included desktop-router config:

| Area | What's on |
|---|---|
| **NSS data plane** | `kmod-qca-nss-drv` + the `kmod-qca-ppe-nss` glue |
| **Connection offload** | ECM (`kmod-qca-nss-ecm`), PPPoE manager (`kmod-qca-nss-drv-pppoe`) — IPv4 NAT, IPv6 routing, PPPoE-over-VLAN |
| **Bridge offload** | `kmod-qca-nss-drv-bridge-mgr` — wired LAN bridging in hardware |
| **Multicast** | `kmod-qca-mcs` — same-subnet multicast hardware-bridged to snooped members |
| **SQM** | NSS qdiscs (`-qdisc`/`-igs`) + `sqm-scripts-nss` (`nss-edma.qos`) + `luci-app-sqm` |
| **Wi-Fi** | ath11k NSS offload (wifili) on both radios (`CONFIG_ATH11K_NSS_SUPPORT`) |
| **Diagnostics** | `nss-status` CLI health report + LuCI **Status → NSS Offload** page |
| **Firmware/profile** | `NSS.FW.12.5-210-HK.R`, MEDIUM memory profile (512 MB) |
| **Security** | OpenSSH only (post-quantum KEX, AEAD/ETM, RSA ≥ 3072), `PKG_*` hardening (ASLR/PIE, stack protector, FORTIFY_3, RELRO, seccomp), WAN DROP + BCP38, HTTPS redirect, OQS provider in OpenSSL |
| **Toolchain** | GCC 15 + Graphite, Binutils 2.46, Mold linker, LTO, `-mcpu=cortex-a53+crc+crypto`; ccache off |
| **Userland** | LuCI (SSL), `htop`, `iperf3`, `curl`, BBR |

Toolchain and package pins live in
[`devices/xiaomi_ax3600/config`](devices/xiaomi_ax3600/config).

## Enable the rest in your fork

These are build-verified and wired in code, but **off by default** because the
reference network does not use them. Add the package to
`devices/xiaomi_ax3600/config` and rebuild:

| Feature | Add to config | Notes |
|---|---|---|
| Routed L3 multicast (IPTV WAN→LAN) | `CONFIG_PACKAGE_igmpproxy=y` (or `smcroute`) | ECM offloads each kernel MFC entry to the PPE; needs a real WAN multicast source and a two-VIF topology. See [`docs/CUSTOMIZE.md`](docs/CUSTOMIZE.md). |
| MAP-T / 464XLAT | `CONFIG_PACKAGE_kmod-nat46=y` | nat46 headers + QCA MAP-T exports are staged in the tree. |
| VXLAN | `CONFIG_PACKAGE_kmod-vxlan=y` | fdb/age-update offload via kernel patch `0972`. |
| MACVLAN | `CONFIG_PACKAGE_kmod-macvlan=y` | ECM support via kernel patch `0962`. |
| GRE | `CONFIG_PACKAGE_kmod-gre=y` | ECM GRE support builds. |

Not available on this platform/firmware: IPsec (ESP) offload, TLS/DTLS, Wi-Fi
mesh, and CoDel ECN marking. See the
[Limitations](https://github.com/JuliusBairaktaris/openwrt-nss-edma/wiki/Limitations-and-Roadmap)
page.

---

## Measured results

AX3600 (IPQ8071A, 512 MB), `NSS.FW.12.5-210`, kernel 6.18 — details in the
[wiki](https://github.com/JuliusBairaktaris/openwrt-nss-edma/wiki):

| Metric | Host path | NSS offload |
|---|---|---|
| 311 Mbit/s PPPoE NAT | ~42 % of one core (softirq) | **~99.7 % CPU idle** |
| SQM at 285 Mbit ingress | CPU-bound | **258 Mbit goodput, ~99 % idle** |
| RTT under shaped load | bufferbloat | **16 ms avg vs 20 idle — flat** |
| Wi-Fi data path | mac80211/ath11k on the CPU | **wifili on the NSS cores** |

---

## Build it yourself

Everything is parameterized in the `env:` block of
[`.github/workflows/build.yml`](.github/workflows/build.yml) — fork the repo,
edit, and the pipeline builds on push. Or build locally:

```sh
git clone --branch nss-edma-rework https://github.com/JuliusBairaktaris/openwrt-nss-edma openwrt
cd openwrt
cp feeds.conf.default feeds.conf
echo "src-git nss https://github.com/JuliusBairaktaris/nss-packages.git;edma-nss" >> feeds.conf
./scripts/feeds update -a && ./scripts/feeds install -a
cp ../Qualcommax_NSS_Builder/devices/xiaomi_ax3600/config .config
make defconfig && make -j"$(nproc)"
```

The overlay files (`nss-up`, uci-defaults, SQM and SSH config) are under
`devices/xiaomi_ax3600/files*/` — copy them into the image with a `files/`
directory or the builder pipeline. See [`docs/CUSTOMIZE.md`](docs/CUSTOMIZE.md)
for the full customization guide and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
for how the pipeline works.

### Repo layout

```
devices/xiaomi_ax3600/
  config                 # the .config (target, toolchain, hardening, NSS packages)
  files/                 # base rootfs overlay (sshd_config, QoL uci-defaults)
  files.edma-nss/        # edma-nss overlay (nss-up, SQM + offload settings)
scripts/                 # check-updates, prepare-build, prune-releases (tested, linted)
docs/                    # CUSTOMIZE.md, ARCHITECTURE.md
.github/workflows/       # build.yml (check → build → prune), lint.yml
```

The pipeline runs `check → build → prune`: `check` resolves the upstream/NSS
ref to a SHA and skips a scheduled build when nothing changed; `build` applies
the config + overlays, compiles, and publishes a release; `prune` keeps the
newest `KEEP` releases. Builds are uncached (fresh runner, reproducible
`SOURCE_DATE_EPOCH`) and the pipeline is linted (`actionlint`, `shellcheck`,
`yamllint`) on every PR.

---

## Contributing

Issues and PRs welcome — see [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Acknowledgements

- **[Ansuel (Christian Marangi)](https://github.com/Ansuel)** — the
  [EDMA rework](https://github.com/openwrt/openwrt/pull/22381) this stack builds on
- **[qosmio](https://github.com/qosmio)** — NSS development, the
  [openwrt-ipq](https://github.com/qosmio/openwrt-ipq) tree, and the Wi-Fi
  offload patch lineage
- **[rodriguezst](https://github.com/rodriguezst)** — original
  [ipq807x-openwrt-builder](https://github.com/rodriguezst/ipq807x-openwrt-builder)
- **OpenWrt community** — the
  [IPQ807x NSS Build thread](https://forum.openwrt.org/t/ipq807x-nss-build/148529)

## Support the project

This is an unpaid, single-maintainer effort. If this work is useful to you,
consider chipping in — it goes toward IPQ807x development and hardware to start
looking into **IPQ50xx** and **IPQ60xx** next.

- **[GitHub Sponsors](https://github.com/sponsors/JuliusBairaktaris)** — zero-fee, GitHub-native
- **[PayPal](https://paypal.me/JuliusBairaktaris)** — one-off donations

Thank you!

## License

[GPL-2.0](LICENSE), consistent with OpenWrt.
