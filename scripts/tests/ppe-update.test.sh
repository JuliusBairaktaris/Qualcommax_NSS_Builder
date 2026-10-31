#!/usr/bin/env bash
# Tests for the package handling of ppe-update (devices/common/files.ppe-nss/usr/sbin).
# The apk "unable to select" report in fixtures/ is apk 3's own output; the restore
# runs against a stub apk that refuses what the feeds of a new release would.
#
# Run with: bash scripts/tests/ppe-update.test.sh

set -euo pipefail

here="$(cd "$(dirname -- "$0")" && pwd)"
script="$here/../../devices/common/files.ppe-nss/usr/sbin/ppe-update"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
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

# Runs ppe-update functions in sh with the stub apk first on PATH.
ppe() {
  PATH="$tmp/bin:$PATH" PPE_UPDATE_LIB=1 PPE_RELEASE=/dev/null \
    PPE_STATE="$tmp/state" PPE_WORK="$tmp/work" sh -c ". '$script'; $1" 2>/dev/null
}

# Case 1: the report names the packages apk cannot install, conflicts included.
got="$(ppe "unresolved '$here/fixtures/apk-unable-to-select.txt'" | tr '\n' ' ')"
check "unresolved names missing and conflicting packages" \
  "ip-full ip-tiny kmod-ath10k-ct-smallbuffers nss-firmware " "$got"

# The stub apk: a package the feeds lack fails, pbr needs ip-tiny removed in the
# same transaction (it takes ip-full, which conflicts with it), and every
# successful add is recorded.
mkdir -p "$tmp/bin" "$tmp/state"
cat >"$tmp/bin/apk" <<STUB
#!/bin/sh
[ "\$1" = update ] && exit 0
shift
case " \$* " in *" kmod-ath10k-ct-smallbuffers "*) exit 1 ;; esac
case " \$* " in *" pbr "*) case " \$* " in *" !ip-tiny "*) ;; *) exit 1 ;; esac ;; esac
echo "\$*" >>"$tmp/added"
STUB
printf '#!/bin/sh\nexit 0\n' >"$tmp/bin/lock"
printf '#!/bin/sh\nexit 0\n' >"$tmp/bin/logger"
chmod +x "$tmp/bin/"*

# Case 2: one package the new release lacks no longer drops the others.
printf '%s\n' '!ip-tiny' ath10k-firmware-qca9887-ct kmod-ath10k-ct-smallbuffers \
  luci-app-pbr pbr tailscale >"$tmp/state/packages"
ppe cmd_restore || true
check "restore keeps only the package that cannot be installed" \
  "kmod-ath10k-ct-smallbuffers" "$(cat "$tmp/state/packages" 2>/dev/null)"
check "restore installs the rest, pbr with its removal" \
  "!ip-tiny pbr" "$(grep -x '!ip-tiny pbr' "$tmp/added")"
check "restore installs tailscale" "1" "$(grep -cxE '(!ip-tiny )?tailscale' "$tmp/added")"

# Case 3: a list that installs in one go is cleared.
rm -f "$tmp/added"
printf '%s\n' '!ip-tiny' pbr tailscale >"$tmp/state/packages"
ppe cmd_restore
check "restore clears an installed list" "absent" \
  "$([[ -e "$tmp/state/packages" ]] && echo present || echo absent)"
check "restore installs it in one transaction" "!ip-tiny pbr tailscale" "$(cat "$tmp/added")"

exit "$fail"
