# Adding a new device

The repo ships with `devices/xiaomi_ax3600/` as the reference. Each device has a shared base
`config` plus a small `config.<variant>` fragment per variant it should build (see
[`VARIANTS.md`](VARIANTS.md)). Adding a device is a directory copy plus a `builder.yml` edit.

## Steps

1. **Pick an id.** Use the OpenWrt board id (`make menuconfig` → Target Profile shows it).
   Examples: `xiaomi_ax9000`, `dynalink_dl-wrx36`, `redmi_ax6`. Lowercase, underscores.

2. **Generate the `.config` for that device.** Start from an existing variant so you diff against
   the same tree it will build on:
   ```sh
   git clone --branch nss-edma-rework https://github.com/JuliusBairaktaris/openwrt-nss-edma openwrt
   cd openwrt
   cat ../devices/xiaomi_ax3600/config ../devices/xiaomi_ax3600/config.edma-nss > .config
   make menuconfig          # set Target Profile to your device, adjust packages, save
   ./scripts/diffconfig.sh > /tmp/full.config
   ```
   `diffconfig.sh` produces a minimal `.config` (only deltas from the default) — exactly what this
   template wants.

3. **Split it into base + fragment(s).** Put device-wide, variant-agnostic lines (target profile,
   toolchain, hardening, packages) in `config`; put variant-only lines (NSS modules, or EDMA/cake)
   in `config.<variant>`:
   ```sh
   mkdir -p devices/<id>
   # devices/<id>/config         <- shared base
   # devices/<id>/config.edma-nss     <- variant-only lines
   # devices/<id>/config.edma    <- EDMA-only lines
   ```
   Only create the fragments for variants this device should build.

4. **(Optional) Add rootfs overlays.** Copied to the image root, later layer wins:
   - `devices/<id>/files/` — both variants (e.g. `etc/ssh/sshd_config` → `chmod 0600`,
     `etc/uci-defaults/99-*`, `etc/rc.local`)
   - `devices/<id>/files.<variant>/` — variant-specific (e.g. SQM + flow-offload defaults)
   - `common/files/` — shared by every device

5. **Point a variant at the device** in `builder.yml`:
   ```yaml
   variants:
     - id: nss
       device: <id>
       ...
   ```
   Set `target:` to the device's `bin/targets/<family>/<subtarget>` if it isn't `qualcommax/ipq807x`.

6. **Build.** Push (NSS builds automatically) or **Run workflow** to pick a variant.

## Verifying locally before push

```sh
yq -V                                                          # yq v4.x
EVENT_NAME=workflow_dispatch VARIANT_INPUT=all \
  bash scripts/load-config.sh                                  # prints the matrix, exits 0
```

`load-config.sh` fails fast if `devices/<id>/config` or a referenced `config.<variant>` fragment is
missing — that usually means the id is wrong or you forgot a fragment.

## Tips

- **Don't** check in the full upstream `.config` (~3000 lines). Use `diffconfig.sh` output — it
  survives upstream churn far better.
- **Do** comment package additions so future-you knows why a package is pinned.
- The artifact/release path follows each variant's `target:` in `builder.yml`, so a device on a
  different SoC family just needs the right `target:` — no workflow edits.
