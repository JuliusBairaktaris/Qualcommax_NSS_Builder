# Contributing

Thanks for your interest. Three kinds of contribution are particularly valuable:

1. **A new device under `devices/<id>/`.** Fork, build, verify, PR. See [`docs/ADD_A_DEVICE.md`](docs/ADD_A_DEVICE.md).
2. **A new variant** (a different upstream/feeds/config recipe) under `builder.yml` `variants:`. See [`docs/VARIANTS.md`](docs/VARIANTS.md).
3. **Patches in `patches/`** (or `patches/<variant>/`) that fix upstream regressions or enable a config combination that doesn't work otherwise.

## Before opening a PR

- Run `scripts/tests/prune-releases.test.sh` if you touched `scripts/prune-releases.sh`.
- Run `EVENT_NAME=workflow_dispatch VARIANT_INPUT=all bash scripts/load-config.sh` if you touched `builder.yml`, `scripts/load-config.sh`, or added a device/variant — it validates the selection and prints the matrix.
- The **Lint** workflow runs `actionlint`, `shellcheck`, and `yamllint` on every PR — if it goes red, fix the issue rather than disabling the check.
- Keep changes focused. A PR that changes the workflow *and* adds a device is harder to review than two PRs.

## Commit messages

Conventional commits — `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`, `ci:`. Body explains the *why*.

## Coding style

- Bash scripts: `set -euo pipefail` at the top, `source scripts/lib/log.sh`, two-space indent.
- YAML: two-space indent, no trailing whitespace, `# comments` for non-obvious values.
- Markdown: hard-wrap is fine but not required.

## Reporting bugs

Use the issue templates. The "build failure" template asks for the run URL and the device id, which is everything needed to triage 95% of issues.
