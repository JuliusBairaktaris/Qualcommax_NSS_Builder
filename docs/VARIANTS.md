# Variants

A **variant** is one self-contained build recipe: its own upstream tree, feeds, device
config fragment, and release prefix. `builder.yml` declares a list of them, and the
`build` workflow runs a matrix over that list. The shipped variant is `edma-nss`.

## The `edma-nss` variant

| | `edma-nss` |
|---|---|
| OpenWrt tree | [`JuliusBairaktaris/openwrt-nss-edma`](https://github.com/JuliusBairaktaris/openwrt-nss-edma) @ `nss-edma-rework` |
| NSS packages | [`JuliusBairaktaris/nss-packages`](https://github.com/JuliusBairaktaris/nss-packages) @ `edma-nss` (added as the `nss` feed) |
| Ethernet driver | upstream `qca-edma`/`qca-ppe` (PR #22381), firmware data plane attached at runtime |
| Offload | ECM NAT/PPPoE, NSS SQM (`nss-edma.qos`), ath11k Wi-Fi offload (wifili) |
| When it builds | schedule + push (auto) — rebuilds when either source tree moves |

The tree is OpenWrt `main` + the [PR #22381](https://github.com/openwrt/openwrt/pull/22381)
EDMA rework + the NSS integration series (data-plane glue, device tree, Wi-Fi offload patch
sets) layered on top — a linear, rebased branch, so it is checked out and built as-is with
no PR merging at build time. `check-updates` tracks **both** the OpenWrt tree and the
nss-packages feed: a push to either triggers a rebuild (skipped while both are unchanged).

Architecture, runtime model, measured results and limitations are documented in the
[openwrt-nss-edma wiki](https://github.com/JuliusBairaktaris/openwrt-nss-edma/wiki).
The runtime contract in short: the image **boots on the plain host stack** (NSS modules
load but stay inert; Wi-Fi starts in host mode), and `/usr/sbin/nss-up` — run from
`rc.local`, shipped in `files.edma-nss/` — arms the data plane, boots the NSS firmware,
moves the radios onto the wifili path and starts ECM + SQM. A reboot always returns to
the host-only stack.

The historical `nss` (qosmio `openwrt-ipq` tree) and `edma` (PR #22381 without NSS)
variants were retired when `edma-nss` superseded both; their recipes live in the git
history if you want to resurrect one as a custom variant.

`merge_prs: [<n>, ...]` is still supported as a general mechanism for any variant — each listed
PR is fetched from the variant's `upstream.repo` and `git merge --no-commit`'d onto `ref` at
build time (kept uncommitted so `SOURCE_DATE_EPOCH` stays pinned). `edma-nss` does not use it.

## Adding a variant

1. Add an entry under `variants:` in `builder.yml`:

   ```yaml
   - id: myvariant
     # scheduled: false               # optional; omit to build on schedule/push like the others
     upstream:
       repo: owner/openwrt
       ref: some-branch               # branch, tag, or 40-char SHA
     # nss_packages: { repo: ..., ref: ... }   # only if it needs the NSS feed
     # merge_prs: [12345]                       # optional: PRs to merge onto `ref`
     # patches: myvariant                       # optional: also apply patches/myvariant/*.patch
     target: qualcommax/ipq807x       # bin/targets/<target>/
     device: xiaomi_ax3600
     feeds: []                        # custom src-git feeds, if any
     release:
       prefix: myvariant
   ```

2. Add the config fragment `devices/<device>/config.myvariant` (appended to the shared
   `config` base). Put only what differs from the base here.

3. (Optional) Add `devices/<device>/files.myvariant/` for variant-specific overlay files
   (applied after `common/files/` and `devices/<device>/files/`, so it wins).

4. Validate locally:

   ```sh
   EVENT_NAME=workflow_dispatch VARIANT_INPUT=myvariant bash scripts/load-config.sh
   ```

   It fails fast if the device dir, base config, or `config.myvariant` fragment is missing.

5. Build it from **Actions → Build → Run workflow → variant: `myvariant`** (it also appears
   under `all`).

## Release prefixes and pruning

Each variant's releases are tagged `<prefix>-<timestamp>-<run id>` and pruned independently:
`scripts/prune-releases.sh` keeps the newest `release.keep` releases **within each prefix**,
so each variant's release history is pruned independently.
