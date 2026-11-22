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

# The stub apk: an update fails as apk does on a feed signed with a key the image
# does not trust while $tmp/untrusted exists, a package the feeds lack fails, pbr needs ip-tiny removed in the
# same transaction (it takes ip-full, which conflicts with it), and every
# successful add is recorded.
mkdir -p "$tmp/bin" "$tmp/state"
cat >"$tmp/bin/apk" <<STUB
#!/bin/sh
if [ "\$1" = update ]; then
  [ -e "$tmp/untrusted" ] || exit 0
  echo "WARNING: updating and opening https://example/packages.adb: UNTRUSTED signature"
  exit 1
fi
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

# Case 4: feeds signed with another key are named as that, and stop an update
# unless it is forced. The router's world is not on this host, so the kept
# list and the release lookup are given.
# shellcheck disable=SC2016
given='mkdir -p "$WORK"; LATEST=r2 TAG=r1 IMAGE=img SIZE=0; extras() { echo usteer; }; lookup() { :; }'
touch "$tmp/untrusted"
check "preflight names an untrusted feed" \
  "1 the package feeds of r2 are signed with a key this image does not trust" \
  "$(ppe "$given; preflight; echo \$? \$(cat \$WORK/check.err)")"
check "update stops on an unchecked release" "2" "$(ppe "$given; cmd_update '' ''; echo \$?" || echo $?)"
# Forced, it goes on to the memory check, which a zero-size image fails.
PATH="$tmp/bin:$PATH" PPE_UPDATE_LIB=1 PPE_RELEASE=/dev/null PPE_STATE="$tmp/state" PPE_WORK="$tmp/work" \
  sh -c ". '$script'; $given; cmd_update '' -f" >/dev/null 2>"$tmp/forced" || true
check "a forced update flashes without the check" \
  "the package feeds of r2 are signed with a key this image does not trust; flashing without the package check" \
  "$(grep -m1 'flashing without' "$tmp/forced")"
rm -f "$tmp/untrusted"
check "preflight passes a trusted feed" "0" "$(ppe "$given; preflight; echo \$?")"

# Case 5: start returns at once and holds none of the caller's descriptors, or
# rpcd would not answer LuCI before the update ends. The reader of the pipe
# sees its end only when every writer has closed it.
begin=$(date +%s)
PPE_LOG="$tmp/log" ppe 'cmd_update() { sleep 5; }; cmd_start' | cat
check "start does not keep the caller's stdout" "1" "$(( $(date +%s) - begin < 4 ))"
check "start empties the log before it returns" "" "$(cat "$tmp/log")"
PPE_LOG="$tmp/log" ppe 'cmd_update() { die stopped; }; cmd_start'
sleep 1
check "start logs the exit status of an update that dies" "stopped exit 2" "$(tr '\n' ' ' <"$tmp/log" | sed 's/ $//')"
# The shell that starts the update has let go of both pipes by the time it
# exits, however the scheduler orders it and the update: one CPU makes the
# update run last. rpcd misses a pipe closed after the exit.
printf '#!/bin/sh\nPPE_UPDATE_LIB=1 PPE_RELEASE=/dev/null PPE_LOG=%s . %s\ncmd_update() { sleep 1; }\ncmd_start\n' \
  "$tmp/log" "$script" >"$tmp/start"
chmod +x "$tmp/start"
check "start has closed its pipes when it exits" "0 of 200 runs left a pipe open when the command exited" \
  "$(taskset -c 0 python3 "$here/exec-eof.py" 200 "$tmp/start")"

exit "$fail"
