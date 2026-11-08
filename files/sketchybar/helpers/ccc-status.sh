#!/usr/bin/env bash
# Carbon Copy Cloner status probe for items/ccc.lua.
#
# Prints tab-separated lines consumed by ccc.lua:
#   running<TAB>1|0        (1 while any CCC task is running)
#   percent<TAB><0-100|-1> (only while running; -1 = indeterminate)
#   phase<TAB><text>       (only while running; e.g. "Compare and copy")
#
# Kept in helpers/ (rather than inlined in ccc.lua) so CI can run shellcheck
# on it. Parses `ccc -i` output with awk, avoiding python3 (which can pop the
# "install developer tools" dialog on machines without the CLT).
#
# `ccc -i` prints one pipe-separated line per task:
#   Task Name|state|percent|bytesCopied|phase|currentPath
# where state is "stopped", "running" or "running (pausable)", and percent
# is already a 0-100 value (matching the "Progress: X.YYYYYY%" line that
# `ccc -w` prints), or -1.000000 when progress is indeterminate. If several
# tasks run at once, the first one wins.
#
# `ccc` talks to CCC's privileged helper daemon over XPC before doing anything
# and blocks forever if the daemon does not answer: this happened on
# 2026-11-07 when Homebrew upgraded the CCC cask while the old helper kept
# running. SketchyBar polls this script every 30 s and never reaps it, so
# each hung run leaked a bash/ccc/awk trio until the per-user process limit
# (kern.maxprocperuid) was hit and nothing on the machine could fork. The
# watchdog below kills `ccc -i` after CCC_STATUS_TIMEOUT seconds (a healthy
# run takes ~0.6 s) and reports "not running" instead. Pure bash: SketchyBar
# runs this with /bin/bash 3.2 and macOS ships no `timeout`.
set -u

ccc="/Applications/Carbon Copy Cloner.app/Contents/MacOS/ccc"
timeout="${CCC_STATUS_TIMEOUT:-10}"

if [ ! -x "$ccc" ]; then
  printf 'running\t0\n'
  exit 0
fi

out="$(mktemp -t ccc-status)" || exit 1
trap 'rm -f "$out"' EXIT

"$ccc" -i >"$out" 2>/dev/null &
ccc_pid=$!
# The subshell's stderr is dropped so it stays silent when its sleep is
# killed below.
(
  sleep "$timeout"
  # SIGKILL: the hung process sits in mach_msg and may ignore SIGTERM.
  kill -KILL "$ccc_pid"
) 2>/dev/null &
watchdog=$!

# Park stderr on fd 3 while reaping: bash reports jobs that die by signal
# ("Killed: 9", "Terminated: 15") on stderr, and one of the two always does.
exec 3>&2 2>/dev/null
wait "$ccc_pid"
ccc_status=$?
# Tear down the watchdog and its sleep so nothing outlives this script.
pkill -P "$watchdog"
kill "$watchdog"
wait "$watchdog"
exec 2>&3 3>&-

# 137 = killed by the watchdog; any other failure also means "unknown", which
# the bar shows as "not running" rather than leaving a stale indicator.
if [ "$ccc_status" -ne 0 ]; then
  if [ "$ccc_status" -eq 137 ]; then
    echo "ccc-status: ccc -i did not answer within ${timeout}s; killed" >&2
  fi
  printf 'running\t0\n'
  exit 0
fi

line="$(awk -F'|' '$2 ~ /^running/ { print; exit }' "$out")"

if [ -z "$line" ]; then
  printf 'running\t0\n'
  exit 0
fi

printf 'running\t1\n'
printf '%s\n' "$line" | awk -F'|' '{
  percent = $3 + 0
  if (percent >= 0) {
    printf "percent\t%d\n", percent + 0.5
  } else {
    printf "percent\t-1\n"
  }
  printf "phase\t%s\n", $5
}'
