# Architecture

This is a tour of the moving parts. If you're trying to debug a build or extend the template,
start here. For the NSS-vs-EDMA design, see [`VARIANTS.md`](VARIANTS.md).

## Pipeline

```
config -> check-updates -> build (matrix over variants) -> prune
```

| Job | File | Runtime | Purpose |
|---|---|---|---|
| `config` | `build.yml` → `scripts/load-config.sh` | ~10s | Parses `builder.yml`, selects the variants for this event (the `scheduled: true` set, or the `workflow_dispatch` choice), emits the build **matrix** + global release settings. Validates each selected variant's device dir, base config, and `config.<id>` fragment up front. |
| `check-updates` | `build.yml` → `scripts/check-updates.sh` | ~15s | Resolves each variant's upstream (and NSS) ref to a commit SHA via `git ls-remote`, then drops variants whose latest release for that prefix already records the SHA(s). Manual runs always build. Emits the **filtered** matrix + `has_builds`. |
| `build` | `build.yml` → `scripts/prepare-build.sh` | 2-6h | A matrix job (`fail-fast: false`). For each variant: checks out its upstream at the pinned SHA, merges any `merge_prs`, runs `prepare-build.sh` (feeds, base+fragment `.config`, overlays), sets reproducible-build env, compiles, uploads the artifact, creates the GitHub Release. |
| `prune` | `build.yml` → `scripts/prune-releases.sh` | ~10s | Keeps the newest `release.keep` releases **per variant prefix** so the variants don't evict each other. Tested in `scripts/tests/prune-releases.test.sh`. |

## Why a matrix over `variants`?

NSS and EDMA are different upstreams, feeds, and configs that must never be combined into one
image. Modelling each as a self-describing entry in a `variants:` list — then fanning out with a
GitHub matrix — makes them equally first-class. Adding a third variant (or a per-device split) is a
`builder.yml` edit, not a workflow rewrite. `fail-fast: false` keeps a broken EDMA build from taking
down the scheduled NSS release.

## Why split into jobs?

- **Cheap config/selection errors** — a typo in `builder.yml` fails `config` in ~10s, not after a 4h build.
- **One network step** — `check-updates` does all the SHA resolution and "did anything change?" logic in one place, so `build` is pure compile.
- **Re-runnable prune** — if cleanup fails, re-run just that job.
- **Clear failure attribution** — each variant is its own red/green node in the Actions UI.

## Why no caching?

1. **Predictability.** Every release is built from a clean tree, so reproducing locally matches CI.
2. **Cache-poisoning surface.** OpenWrt's build dir is 10+ GB; corrupted caches produce broken images that look fine.
3. **Size limits.** OpenWrt builds blow past `actions/cache` limits anyway.

ccache is also disabled (`# CONFIG_CCACHE is not set` in the base config) since it's a no-op without persistent storage.

## Reproducibility note

`SOURCE_DATE_EPOCH` is taken from the checked-out upstream commit (`git show -s --format=%ct HEAD`).
The EDMA `merge_prs` step merges with `--no-commit`, so HEAD — and therefore the epoch — stays pinned
to that upstream commit even though the work tree carries the PR. The EDMA image is intentionally
*current* (latest `main` + latest PR head each build), so it is less bit-for-bit reproducible than the
SHA-pinned NSS build; that's the documented trade-off for "refresh on build".

## Why `builder.yml`?

A single fork-edit surface. Anything a fork would want to change (which variants, which device, which
upstream, which feeds, how many releases to keep) is YAML. The cron schedule is the one exception —
GitHub Actions requires static cron strings.

## Why `scripts/` instead of inline shell?

Inline shell in YAML is hostile to shellcheck, testing, and diffing. So all non-trivial logic lives in
`scripts/`, gets `set -euo pipefail`, sources `scripts/lib/log.sh`, and is reachable from `bash`
directly for local debugging. (The old `check-updates` inline block is now `scripts/check-updates.sh`
for exactly this reason.)

## Test strategy

`prune-releases.sh` has unit tests — it has a clear input/output contract (JSON list → tags to
delete), is destructive on failure, and previously hid a "keep last N" bug for months. The new
per-prefix filtering is covered too. `load-config.sh` and `check-updates.sh` are exercised by running
them directly (they print the matrix and fail fast on bad input); the rest orchestrate `make`, which
isn't usefully unit-testable, and are guarded by `actionlint` + `shellcheck`.

## Fork health checks

1. Watch the **Lint** workflow (cheap, runs on every push).
2. Watch the first scheduled **Build** run after a fork — it should produce a `main-nss-*` release within ~3-6h.
3. Trigger an `edma` build manually and confirm it produces an `edma-*` release.
4. After a few builds, check **Releases** has at most `release.keep` entries *per prefix*.
