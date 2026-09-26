#!/usr/bin/env bash
# Regression fixtures for the macOS Time Machine status probe (no backup needed).
set -eu
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# The mock expands these variables when invoked, not when created.
# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$TM_STATUS"\nexit "${TM_EXIT:-0}"\n' > "$tmp/tmutil"
chmod +x "$tmp/tmutil"
export PATH="$tmp:$PATH"

check() {
  local name="$1" expected="$2" actual
  export TM_STATUS="$3"
  actual="$(bash "$root/files/sketchybar/helpers/timemachine-status.sh")"
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL %s\nExpected:\n%s\nActual:\n%s\n' "$name" "$expected" "$actual" >&2
    exit 1
  fi
  printf 'PASS %s\n' "$name"
}

check idle $'running\t0\nphase\tIdle' $'Running = 0;\nPercent = "-1";'
for phase in PreparingBackup Verifying Finishing ThinningPostBackup FuturePhase; do
  check "$phase ignores stale progress" "$(printf 'running\t1\nphase\t%s' "$phase")" \
    "$(printf 'Running = 1;\nBackupPhase = %s;\nPercent = "0.73";\nFractionOfProgressBar = "0.2";\nTimeRemaining = 100;' "$phase")"
done
check copying $'running\t1\nphase\tCopying\npercent\t42\nremaining\t120' \
  $'Running = 1;\nBackupPhase = Copying;\nPercent = "0.42";\nFractionOfProgressBar = "0.8";\nTimeRemaining = "120";'
check missing $'running\t1\nphase\tCopying' $'Running = 1;\nBackupPhase = Copying;'
for percent in -1 1.2 garbage; do
  check "invalid percent $percent" $'running\t1\nphase\tCopying' \
    "$(printf 'Running = 1;\nBackupPhase = Copying;\nPercent = "%s";\nTimeRemaining = -1;' "$percent")"
done
check unknown $'running\t1\nphase\tWorking' 'Running = 1;'
check data $'running\t1\nphase\tCopying\nbytes\t42000000000\ntotal_bytes\t100000000000' \
  $'Running = 1;\nBackupPhase = Copying;\nbytes = 42000000000;\ntotalBytes = 100000000000;'
check 'ignore stale data' $'running\t1\nphase\tVerifying' \
  $'Running = 1;\nBackupPhase = Verifying;\nbytes = 420;\ntotalBytes = 1000;'
check 'invalid data' $'running\t1\nphase\tCopying' \
  $'Running = 1;\nBackupPhase = Copying;\nbytes = -1;\ntotalBytes = 0;'
export TM_EXIT=1
check failure $'running\t0\nphase\tStatus unavailable' ''
