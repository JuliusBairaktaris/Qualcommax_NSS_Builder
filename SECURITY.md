# Security

## Supported versions

Only the **latest release** is supported. Older releases are routinely deleted by the prune job.

## Reporting a vulnerability

This template builds firmware images. There are two distinct vulnerability classes:

1. **Build pipeline** (this repo's workflow, scripts, default config) — open a private security advisory via GitHub: **Security -> Report a vulnerability**.
2. **OpenWrt itself, NSS drivers, packages** — please report to the source project: [JuliusBairaktaris/openwrt-nss-edma](https://github.com/JuliusBairaktaris/openwrt-nss-edma) (the OpenWrt fork, rebased directly onto openwrt/main) and its [nss-packages](https://github.com/JuliusBairaktaris/nss-packages) feed, or [openwrt/openwrt](https://github.com/openwrt/openwrt) / the relevant package maintainer for stock components. This repo only assembles those sources.

Please do not open a public issue for a security report.

## Hardening posture (default device only)

The reference Xiaomi AX3600 build enables:
- OpenSSH with post-quantum KEX (ML-KEM 768, sntrup761), Dropbear disabled
- `PKG_ASLR_PIE_ALL`, `PKG_CC_STACKPROTECTOR_ALL`, `PKG_FORTIFY_SOURCE_3`, `PKG_RELRO_FULL`, `USE_SECCOMP`
- WAN input/forward = DROP, BCP38 anti-spoofing
- HTTPS-redirect on uHTTPd, OQS provider in OpenSSL

If you fork and retarget to a different device, **review `devices/<id>/config`** — these are not enabled by default in OpenWrt.
