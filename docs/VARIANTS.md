# Variants

A **variant** is one self-contained build recipe: its own upstream tree, feeds, device
config fragment, and release prefix. `builder.yml` declares a list of them, and the
`build` workflow runs a matrix over that list. The two shipped variants are `nss` and
`edma`; they share everything except the network data path.

## NSS vs EDMA

| | `nss` | `edma` |
|---|---|---|
| Upstream | `qosmio/openwrt-ipq` @ `main-nss` | `openwrt/openwrt` @ `main` + PR #22381 |
| Ethernet driver | NSS data plane (hardware offload) | `qca-edma` (CPU-bound) |
| Proprietary code | NSS firmware + invasive kernel patches | none — all upstreamable |
| Throughput | 2+ Gbps NAT, very low CPU | CPU-limited, but full software CAKE |
| SQM | `sqm-scripts-nss`, `nss-zk.qos` | `sqm-scripts`, `cake` + software flow offload |
| Maintenance | tracks a downstream fork | tracks mainline; PR merged fresh each build |
| When it builds | schedule + push | manual `workflow_dispatch` |

**Why NSS?** Maximum throughput. The IPQ807x NSS cores offload NAT/bridge/VLAN/QoS, so a
1 Gbps+ symmetric line with SQM barely touches the ARM cores. The cost is proprietary NSS
firmware and a heavily-patched kernel that only exists in downstream forks.

**Why EDMA?** A clean, mainline kernel with no binary blobs or out-of-tree patches — easier
to trust and to forward-port. Ethernet runs on the CPU via the upstreamable `qca-edma`
driver, so NAT throughput is lower than NSS (IPQ807x has no PPE hardware to offload to), but
software CAKE gives you real bufferbloat control. Good for people who value an auditable,
upstream-tracking image over peak Gbps.

They are **mutually exclusive** — NSS patches the kernel networking stack invasively, so a
single image is one or the other, never both.

## How EDMA pulls in PR #22381

The `edma` variant sets:

```yaml
upstream:
  repo: openwrt/openwrt
  ref: main             # latest mainline, resolved to a SHA at build time
merge_prs: [22381]      # fetched fresh and merged onto `ref` every build
```

At build time `scripts/prepare-build.sh`:

1. lets `check-updates` resolve `main` to the current commit and checks it out,
2. `git fetch origin pull/22381/head` and `git merge --no-commit --no-ff` it onto that
   commit (kept uncommitted so `SOURCE_DATE_EPOCH` stays pinned to the upstream commit),
3. proceeds with feeds → `.config` → overlays as usual.

So **clicking "Run workflow → variant: edma" always builds the current PR on top of the
current `main`** — there is no vendored patch to refresh. If `main` has drifted far enough
that the PR no longer merges cleanly, the build fails loudly; wait for the PR author to
rebase, then rebuild. Once the PR is merged upstream, drop `merge_prs` and the variant just
tracks `main`.

`merge_prs` is a general mechanism — list any OpenWrt PR numbers and they're merged in order.

## Adding a variant

1. Add an entry under `variants:` in `builder.yml`:

   ```yaml
   - id: myvariant
     scheduled: false                 # true = build on schedule/push; false = manual only
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
so the NSS and EDMA release histories never evict each other.
