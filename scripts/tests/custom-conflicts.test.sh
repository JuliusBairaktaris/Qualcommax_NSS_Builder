#!/usr/bin/env bash
# Tests for scripts/custom-conflicts.py against apk 3's own "unable to select
# packages" reports, taken from failed custom builds.
#
# Run with: bash scripts/tests/custom-conflicts.test.sh

set -euo pipefail

here="$(cd "$(dirname -- "$0")" && pwd)"
script="$here/../custom-conflicts.py"
fail=0

check() {
  local name="$1" want="$2" got="$3"
  if [[ "$got" == "$want" ]]; then
    printf 'PASS  %s\n' "$name"
  else
    printf 'FAIL  %s\n  want: %s\n  got:  %s\n' "$name" "$want" "$got"
    fail=1
  fi
}

list="base-files ip-tiny tc-tiny wpad-openssl ip-full@snapshot tc-full@snapshot -dropbear"

# Case 1: the request names the other variant.
got="$(python3 "$script" "$here/fixtures/apk-variant-requested.txt" "$list" | tr '\n' '|')"
check "a requested variant replaces the image's" \
  "base-files wpad-openssl ip-full@snapshot tc-full@snapshot -dropbear -ip-tiny -tc-tiny|ip-tiny tc-tiny|" "$got"

# Case 2: a dependency of the request (pbr on ip-full) needs the other variant;
# the packages no feed has are not this script's to solve.
got="$(python3 "$script" "$here/fixtures/apk-unable-to-select.txt" "$list" | tail -n1)"
check "a variant a dependency needs replaces the image's" "ip-tiny" "$got"

# Case 3: the wpad builds conflict through two provided names.
got="$(python3 "$script" "$here/fixtures/apk-variant-wpad.txt" "$list" | tail -n1)"
check "another wpad replaces the image's" "wpad-openssl" "$got"

# Case 4: a report without such a pair, and a log without a report, change nothing.
printf 'ERROR: unable to select packages:\n  luci-app-steer (no such package):\n    required by: world[luci-app-steer@snapshot]\n' >"${TMPDIR:-/tmp}/cc.$$"
check "a missing package is left to fail" "" "$(python3 "$script" "${TMPDIR:-/tmp}/cc.$$" "$list")"
check "a log without a report is left to fail" "" "$(python3 "$script" /dev/null "$list")"
rm -f "${TMPDIR:-/tmp}/cc.$$"

exit "$fail"
