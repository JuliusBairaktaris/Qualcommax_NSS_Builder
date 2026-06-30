# Contributing

Thanks for your interest. Particularly valuable contributions:

- **Package or config improvements** to [`devices/xiaomi_ax3600/config`](devices/xiaomi_ax3600/config) or the overlays.
- **Pipeline fixes** to the workflow or `scripts/`.
- **Doc improvements.**

## Before opening a PR

- Run `scripts/tests/prune-releases.test.sh` if you touched `scripts/prune-releases.sh`.
- The **Lint** workflow runs `actionlint`, `shellcheck`, and `yamllint` on every PR — if it goes red, fix the issue rather than disabling the check.
- Keep changes focused.

## Commit messages

Conventional commits — `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`, `ci:`. Body explains the *why*.

## Coding style

- Bash scripts: `set -euo pipefail` at the top, `source scripts/lib/log.sh`, two-space indent.
- YAML: two-space indent, no trailing whitespace, `# comments` for non-obvious values.
- Markdown: hard-wrap is fine but not required.

## Reporting bugs

Use the issue templates. The "build failure" template asks for the run URL and the device id, which is everything needed to triage 95% of issues.
