#!/usr/bin/env bash
# Carbon Copy Cloner status probe for items/ccc.lua.
#
# Prints tab-separated lines consumed by ccc.lua:
#   running<TAB>1|0        (1 while any CCC task is running)
#   percent<TAB><0-100|-1> (only while running; -1 = indeterminate)
#   phase<TAB><text>       (only while running; e.g. "Compare and copy")
#
# Kept in helpers/ (rather than inlined in ccc.lua) so it can be checked by
# checked by shellcheck in CI. Parses `ccc -i` output with awk, avoiding python3 (which
# can pop the "install developer tools" dialog on machines without the CLT).
#
# `ccc -i` prints one pipe-separated line per task:
#   Task Name|state|fraction|bytesCopied|phase|currentPath
# where state is "stopped", "running" or "running (pausable)", and fraction
# is -1.000000 when progress is indeterminate. If several tasks run at once,
# the first one wins.
set -u

ccc="/Applications/Carbon Copy Cloner.app/Contents/MacOS/ccc"

if [ ! -x "$ccc" ]; then
  printf 'running\t0\n'
  exit 0
fi

line="$("$ccc" -i 2>/dev/null | awk -F'|' '$2 ~ /^running/ { print; exit }')"

if [ -z "$line" ]; then
  printf 'running\t0\n'
  exit 0
fi

printf 'running\t1\n'
printf '%s\n' "$line" | awk -F'|' '{
  fraction = $3 + 0
  if (fraction >= 0) {
    printf "percent\t%d\n", fraction * 100 + 0.5
  } else {
    printf "percent\t-1\n"
  }
  printf "phase\t%s\n", $5
}'
