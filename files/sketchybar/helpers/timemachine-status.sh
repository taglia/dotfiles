#!/usr/bin/env bash
# Time Machine status probe for items/timemachine.lua.
#
# Prints tab-separated lines consumed by timemachine.lua:
#   running<TAB>1|0        (1 only while a destination backup is in progress)
#   percent<TAB><0-100>    (only while running)
#
# Kept in helpers/ (rather than inlined in timemachine.lua) so it can be
# checked by shellcheck in CI. Parsing is done with awk against the
# plain-text plist that `tmutil status` prints, avoiding python3 (which can
# pop the "install developer tools" dialog on machines without the CLT).
set -u

status="$(tmutil status 2>/dev/null)"

if printf '%s\n' "$status" | grep -q 'Running = 1;'; then
  printf 'running\t1\n'
  # Top-level keys are indented 4 spaces; the Progress sub-dictionary also
  # contains a Percent key, so anchor on the 4-space indent and take the
  # first match. Percent is a fraction (0-1).
  percent="$(printf '%s\n' "$status" | awk -F'"' '/^    Percent = / { printf "%d", $2 * 100 + 0.5; exit }')"
  printf 'percent\t%s\n' "${percent:-0}"
else
  printf 'running\t0\n'
fi
