#!/usr/bin/env bash
# Smoke tests for prune-releases.sh.
# Pipes synthetic gh release list JSON to the script in DRY_RUN mode and
# verifies the right tags are selected for deletion.
#
# Run with: bash scripts/tests/prune-releases.test.sh

set -euo pipefail

here="$(dirname -- "$0")"
script="$here/../prune-releases.sh"

fail=0

run_case() {
  local name="$1" json="$2" keep="$3" current="$4" want="$5"
  local got
  got="$(REPO=owner/name KEEP="$keep" CURRENT_TAG="$current" \
    DRY_RUN=1 RELEASES_JSON_STDIN=1 \
    bash "$script" <<<"$json" 2>/dev/null \
    | awk '/^  - /{print $2}' \
    | sort)"
  want="$(printf '%s\n' "$want" | sort)"
  if [[ "$got" == "$want" ]]; then
    printf 'PASS  %s\n' "$name"
  else
    printf 'FAIL  %s\n  want: %s\n  got:  %s\n' "$name" "${want//$'\n'/,}" "${got//$'\n'/,}"
    fail=1
  fi
}

# Case 1: 5 releases, keep 2 -> delete the 3 oldest.
five='[
  {"tagName":"r5","publishedAt":"2026-05-05T00:00:00Z"},
  {"tagName":"r4","publishedAt":"2026-05-04T00:00:00Z"},
  {"tagName":"r3","publishedAt":"2026-05-03T00:00:00Z"},
  {"tagName":"r2","publishedAt":"2026-05-02T00:00:00Z"},
  {"tagName":"r1","publishedAt":"2026-05-01T00:00:00Z"}
]'
run_case "keep=2 of 5 deletes 3 oldest" "$five" 2 "" "r3
r2
r1"

# Case 2: only 2 releases, keep 2 -> delete nothing.
two='[
  {"tagName":"r2","publishedAt":"2026-05-02T00:00:00Z"},
  {"tagName":"r1","publishedAt":"2026-05-01T00:00:00Z"}
]'
run_case "keep=2 of 2 deletes nothing" "$two" 2 "" ""

# Case 3: empty list.
run_case "empty list deletes nothing" '[]' 2 "" ""

# Case 4: current tag is among newest -> noop on it; older still pruned.
run_case "keep=2 honors CURRENT_TAG defensively" "$five" 2 "r5" "r3
r2
r1"

# Case 5: unsorted input: still picks correctly by publishedAt.
unsorted='[
  {"tagName":"old","publishedAt":"2026-04-01T00:00:00Z"},
  {"tagName":"new","publishedAt":"2026-05-05T00:00:00Z"},
  {"tagName":"mid","publishedAt":"2026-04-15T00:00:00Z"}
]'
run_case "unsorted input sorted by publishedAt" "$unsorted" 1 "" "old
mid"

# Case 6: KEEP=1 of 5.
run_case "keep=1 of 5 deletes 4 oldest" "$five" 1 "" "r4
r3
r2
r1"

if [[ "$fail" -ne 0 ]]; then
  echo "Some tests failed." >&2
  exit 1
fi

echo "All tests passed."
