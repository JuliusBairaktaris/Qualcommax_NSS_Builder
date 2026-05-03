# Adding a new device

The repo ships with `devices/xiaomi_ax3600/` as the reference. Adding a second device is a directory copy plus a one-line edit.

## Steps

1. **Pick an id.** Use the OpenWrt board id (`make menuconfig` -> Target Profile shows it). Examples: `xiaomi_ax9000`, `dynalink_dl-wrx36`, `redmi_ax6`. Lowercase, underscores.

2. **Generate the `.config` for that device.**
   ```sh
   git clone --branch <upstream-branch> https://github.com/<upstream-repo> openwrt
   cd openwrt
   make menuconfig
   # Set Target Profile to your device, save, exit.
   ./scripts/diffconfig.sh > ../my-device.config
   ```
   `diffconfig.sh` produces a minimal `.config` containing only the deltas from the default — that's exactly what this template wants.

3. **Drop it in.**
   ```sh
   mkdir -p devices/<id>/files
   mv ../my-device.config devices/<id>/config
   ```

4. **(Optional) Add a rootfs overlay.** Anything under `devices/<id>/files/` is copied to the image root. Common entries:
   - `etc/uci-defaults/99-my-defaults` — runs once on first boot
   - `etc/ssh/sshd_config` — gets `chmod 0600` automatically
   - `etc/rc.local` — boot-time hook

   Files shared by all devices go in `common/files/` instead.

5. **Switch the active device.**
   ```yaml
   # builder.yml
   device: <id>
   ```

6. **Push.** The build runs immediately on push (and every 2 hours on cron).

## Verifying locally before push

You can sanity-check the config-loading without a full compile:

```sh
yq -V                             # should print yq v4.x
bash scripts/load-config.sh       # prints resolved config, exits 0
```

If `load-config.sh` fails because `devices/<id>/config` is missing, you got the id wrong.

## Tips

- **Don't** check in the full upstream `.config` (~3000 lines). Use `diffconfig.sh` output. It survives upstream churn far better.
- **Do** comment package additions in `devices/<id>/config` so future-you knows why a package is pinned.
- The artifact path in `build.yml` is `openwrt/bin/targets/qualcommax/ipq807x` — adjust if your device targets a different SoC family.
