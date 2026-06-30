<!--
Thanks for the PR. Filling this in helps reviewers move quickly.
-->

## What

<!-- one or two sentences -->

## Why

<!-- the motivating problem, link to the issue if any -->

## How

<!-- approach + anything non-obvious about the implementation -->

## Verification

- [ ] Lint workflow passes locally (`actionlint`, `shellcheck scripts/*.sh`, `yamllint .github/workflows/`)
- [ ] If `scripts/prune-releases.sh` changed: `bash scripts/tests/prune-releases.test.sh` passes
- [ ] No secrets, tokens, or personal info in the diff
