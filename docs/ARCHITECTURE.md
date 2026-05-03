# Architecture

This is a tour of the moving parts. If you're trying to debug a build or extend the template, start here.

## Pipeline

```
config -> check-updates -> build (compile + release) -> prune
```

| Job | File | Runtime | Purpose |
|---|---|---|---|
| `config` | `.github/workflows/build.yml` -> `scripts/load-config.sh` | ~30s | Parses `builder.yml`, exposes every value as a job output. Single source of truth — every downstream job consumes outputs, nothing reads `builder.yml` directly. |
| `check-updates` | inline in `build.yml` | ~10s | Calls `gh api` to get the current commit on `upstream` and `nss_packages`, compares against the body of the latest release. Skips the build if both SHAs are present (i.e. nothing new). `workflow_dispatch` always builds. |
| `build` | `.github/workflows/build.yml` -> `scripts/prepare-build.sh` | 2-6h | Installs apt deps, checks out OpenWrt at the right SHA, runs `prepare-build.sh`, sets reproducible-build env, downloads sources, compiles, uploads artifact, creates the GitHub Release. |
| `prune` | `.github/workflows/build.yml` -> `scripts/prune-releases.sh` | ~10s | Deletes releases beyond `release.keep`. Tested in `scripts/tests/prune-releases.test.sh`. |

## Why split into jobs?

The original workflow was one 360-minute job that did everything. Splitting buys us:
- **Re-runnable prune** — if cleanup fails, you can re-run just that job.
- **Clear failure attribution** — "build failed" vs "release failed" vs "prune failed" each surface as a separate red node in the Actions UI.
- **Cheaper config errors** — a typo in `builder.yml` fails the `config` job in ~30s instead of after a 4h build.

## Why no caching?

Three reasons:
1. **Predictability.** Every release is built from a clean tree, so reproducing locally matches CI.
2. **Cache poisoning surface.** OpenWrt's build dir is 10+ GB; corrupted caches produce broken images that look fine.
3. **GitHub Actions cache size limits.** OpenWrt builds blow past them anyway.

ccache is also disabled (`# CONFIG_CCACHE is not set` in the device config) since it's a no-op without persistent storage.

## Why `builder.yml`?

A single fork-edit surface. Anything a fork would want to change (which device, which upstream, which feeds, how many releases to keep) is one YAML field. Anything else (workflow internals, scripts) should not need editing.

The cron schedule is the one exception — GitHub Actions requires static cron strings.

## Why `scripts/` instead of inline shell?

Inline shell in YAML is hostile to:
- shellcheck (must be extracted manually)
- testing (the original "keep last 2 releases" logic was wrong for months because no one could test it)
- diffing (a 50-line inline `run:` block is unreadable in PRs)

So all non-trivial logic lives in `scripts/`, gets `set -euo pipefail`, sources `scripts/lib/log.sh`, and is reachable from `bash` directly for local debugging.

## Test strategy

Only one piece of logic has unit tests today: `prune-releases.sh`. That's deliberate — it's the only script that:
- has a clear input/output contract (JSON list -> set of tags to delete)
- is destructive on failure
- previously had a bug that survived for months

The rest of the scripts mostly orchestrate `make`, which isn't usefully unit-testable. They're guarded by `actionlint` + `shellcheck` instead.

## Fork health checks

If you fork this and want to know whether your fork's build is healthy:

1. Watch the **Lint** workflow (cheap, runs on every push).
2. Watch the first scheduled **Build** run after a fork (slower; should produce a release within ~3-6h).
3. After a few builds, check **Releases** has exactly `release.keep` entries.
