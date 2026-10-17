# Architecture

## Workflows

| Workflow | Builds | Release |
|---|---|---|
| `build.yml` | `ppe-nss` of openwrt-ppe-nss, six groups | `ppe-nss-*`, a new one per build |
| `build-ppe.yml` | `ppe-flow-offload`, every board of each subtarget, no NSS | `ppe-offload-test`, one prerelease updated in place |
| `lint.yml` | nothing | runs `actionlint`, `shellcheck` and `yamllint` on workflow and script changes |

## The build.yml pipeline

```mermaid
flowchart LR
    check --> release --> build --> publish --> prune
    check --> stats
```

| Job | Script | Does |
|---|---|---|
| `check` | `scripts/check-updates.sh` | Resolves the `ppe-nss` and `edma-nss` refs to commits. On a scheduled run it skips the build when the latest release already records both. Push and manual runs always build. |
| `stats` | `scripts/download-stats.sh` | Updates the download badge on the `stats` branch, including releases already pruned. |
| `release` | | Opens a draft release and writes its notes, including the source commits. |
| `build` | `scripts/prepare-build.sh` | One job per group. Checks out the source at the resolved commit, sets up feeds, patches, config and overlays, restores the caches, builds, and uploads the sysupgrade images, `sha256sums-<group>.txt` and `config-<group>.buildinfo` into the draft. |
| `publish` | | Publishes the draft once every job succeeded and marks it latest. If any job failed, it deletes the draft. |
| `prune` | `scripts/prune-releases.sh` | Keeps the newest `KEEP` releases of each prefix. |

## Design choices

- **All or nothing.** One release holds every board. A partial release
  would read as "this board is not supported" when only one group failed,
  so a failed job discards the whole draft.
- **Both firmware lines in one image.** The images carry NSS firmware 12.5
  and 11.4 and boot 12.5; `nss-wifi.general.firmware` picks 11.4 for
  802.11s mesh.
- **Groups by RAM.** The ath11k memory profile is fixed at build time for
  the whole image, so boards can only share a build when they share a RAM
  size.
- **Reproducible inputs.** `SOURCE_DATE_EPOCH` is the commit time of the
  checked-out source, with `TZ=UTC`, `LC_ALL=C` and fixed kbuild user and
  host. The images follow the branch tip, so each build pins a commit but
  the next one moves on.
- **Caches.** Verified source downloads and ccache are kept between runs
  (see [CUSTOMIZE.md](CUSTOMIZE.md#caches)). The build tree itself is never
  cached.
- **Scripts, not inline shell.** Logic lives in `scripts/` with
  `set -euo pipefail` and `scripts/lib/log.sh`, so it can be run and
  checked locally.

## Tests

`scripts/tests/prune-releases.test.sh` covers `prune-releases.sh`, which
deletes releases. `check-updates.sh` prints its decision and fails on bad
input. The rest drives `make` and is covered by the lint workflow.
