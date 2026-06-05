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
| Maintenance | tracks a downstream fork | tracks the PR author's branch |
| When it builds | schedule + push (auto) | schedule + push (auto) — rebuilds when the branch moves |

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

## How EDMA tracks PR #22381

The `edma` variant builds the PR author's branch **directly**:

```yaml
upstream:
  repo: Ansuel/openwrt    # PR #22381 author's fork
  ref: qca-edma-rework    # the PR branch tip, resolved to a SHA each run
```

`check-updates` resolves the branch tip to a SHA and `build` checks it out as-is — no merge,
no patch. This is the same mechanism NSS uses, so EDMA **rebuilds automatically whenever Ansuel
pushes** to the branch (and is skipped while the tip is unchanged). You can still force a build
with **Run workflow → variant: edma**.

**Why not merge the PR onto latest `main`?** We tried that first and it broke: the PR pins
out-of-tree drivers (`qca-ppe`, `qca-uniphy`) against a specific state of OpenWrt's phylink PCS
patches. When `main` moved its phylink ahead of the PR (renaming `phylink_config.available_pcs`
→ `num_available_pcs`), the merged tree paired a *new* phylink with the PR's *old* driver pins
and failed to compile. The PR author's branch keeps both in lockstep, so building it directly
just works. Once PR #22381 is merged upstream, point `repo`/`ref` at `openwrt/openwrt` + `main`.

`merge_prs: [<n>, ...]` is still supported as a general mechanism for any variant — each listed
PR is fetched from the variant's `upstream.repo` and `git merge --no-commit`'d onto `ref` at
build time (kept uncommitted so `SOURCE_DATE_EPOCH` stays pinned). `edma` no longer uses it.

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
so the NSS and EDMA release histories never evict each other.
