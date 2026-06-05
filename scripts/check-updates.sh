#!/usr/bin/env bash
# Resolve each candidate variant's upstream (and NSS) commit, decide whether it needs
# a rebuild, and emit the filtered build matrix consumed by the `build` job.
#
# A variant needs a build when:
#   - the event is anything other than `schedule` — a push means the builder config changed
#     and workflow_dispatch is an explicit request, so both always rebuild; OR
#   - on a scheduled tick, the latest release for that variant's prefix does not already
#     record the current upstream SHA (and NSS SHA, when the variant tracks one).
#
# Required tools: jq, git, gh.
#
# Input env:
#   CONFIG_MATRIX  the matrix JSON from load-config.sh ({"include":[ {variant, ...}, ... ]}).
#   EVENT_NAME     github.event_name.
#   REPO           this builder repo (owner/name); defaults to $GITHUB_REPOSITORY.
#   GH_TOKEN       forwarded to gh.
#   GITHUB_OUTPUT  Actions outputs file (when in CI).
#
# Outputs:
#   matrix      filtered {"include":[ {variant,device,target,release_prefix,upstream_repo,
#               upstream_sha,nss_sha}, ... ]} — only variants that need building.
#   has_builds  "true" if at least one variant needs building, else "false".

set -euo pipefail

# shellcheck source=scripts/lib/log.sh
source "$(dirname -- "$0")/lib/log.sh"

: "${CONFIG_MATRIX:?CONFIG_MATRIX required (output of load-config.sh)}"
EVENT_NAME="${EVENT_NAME:-}"
REPO="${REPO:-${GITHUB_REPOSITORY:-}}"
command -v jq >/dev/null || log::die "jq is required"
command -v git >/dev/null || log::die "git is required"

# Resolve a ref to a commit SHA. A 40-hex ref passes through; otherwise ask the remote.
resolve_sha() {
  local repo="$1" ref="$2" sha
  if [[ "$ref" =~ ^[0-9a-f]{40}$ ]]; then
    printf '%s\n' "$ref"
    return 0
  fi
  sha="$(git ls-remote "https://github.com/$repo" "$ref" | awk 'NR==1{print $1}')"
  [[ -n "$sha" ]] || log::die "could not resolve $repo@$ref"
  printf '%s\n' "$sha"
}

# Latest non-draft release body for a tag prefix (empty if none).
latest_body_for_prefix() {
  local prefix="$1"
  [[ -n "$REPO" ]] || { printf '%s' ""; return 0; }
  gh api "repos/$REPO/releases" --jq \
    "[.[] | select(.draft|not) | select(.tag_name | startswith(\"${prefix}-\"))] | sort_by(.created_at) | reverse | .[0].body // \"\"" \
    2>/dev/null || printf '%s' ""
}

out='[]'

while IFS= read -r row; do
  variant="$(jq -r '.variant'        <<<"$row")"
  device="$(jq -r '.device'          <<<"$row")"
  target="$(jq -r '.target'          <<<"$row")"
  prefix="$(jq -r '.release_prefix'  <<<"$row")"
  up_repo="$(jq -r '.upstream_repo'  <<<"$row")"
  up_ref="$(jq -r '.upstream_ref'    <<<"$row")"
  nss_repo="$(jq -r '.nss_repo'      <<<"$row")"
  nss_ref="$(jq -r '.nss_ref'        <<<"$row")"

  up_sha="$(resolve_sha "$up_repo" "$up_ref")"
  nss_sha=""
  if [[ -n "$nss_repo" && "$nss_repo" != "null" ]]; then
    nss_sha="$(resolve_sha "$nss_repo" "$nss_ref")"
  fi

  if [[ "$EVENT_NAME" != "schedule" ]]; then
    # push (builder config changed) or manual dispatch (explicit) -> always rebuild.
    need=true
  else
    # scheduled tick -> only rebuild variants whose upstream moved since the last release.
    body="$(latest_body_for_prefix "$prefix")"
    if [[ "$body" == *"$up_sha"* ]] && { [[ -z "$nss_sha" ]] || [[ "$body" == *"$nss_sha"* ]]; }; then
      need=false
    else
      need=true
    fi
  fi

  log::info "$variant: $up_repo@$up_ref -> ${up_sha:0:12}${nss_sha:+  nss ${nss_sha:0:12}}  build=$need"

  if [[ "$need" == "true" ]]; then
    entry="$(jq -nc \
      --arg variant "$variant" --arg device "$device" --arg target "$target" \
      --arg release_prefix "$prefix" --arg upstream_repo "$up_repo" \
      --arg upstream_sha "$up_sha" --arg nss_sha "$nss_sha" \
      '{variant:$variant, device:$device, target:$target, release_prefix:$release_prefix,
        upstream_repo:$upstream_repo, upstream_sha:$upstream_sha, nss_sha:$nss_sha}')"
    out="$(jq -c --argjson e "$entry" '. + [$e]' <<<"$out")"
  fi
done < <(jq -c '.include[]' <<<"$CONFIG_MATRIX")

n="$(jq 'length' <<<"$out")"
matrix="$(jq -c '{include: .}' <<<"$out")"
has_builds="$([[ "$n" -gt 0 ]] && echo true || echo false)"

log::info "variants needing a build: $n"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## Upstream check"
    jq -r '.include[] | "- `\(.variant)`: `\(.upstream_repo)` -> `\(.upstream_sha[0:12])`"' <<<"$matrix" \
      || echo "- (nothing to build)"
    echo "- has_builds: **$has_builds**"
  } >>"$GITHUB_STEP_SUMMARY"
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "matrix=$matrix"
    echo "has_builds=$has_builds"
  } >>"$GITHUB_OUTPUT"
fi
