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
  # The menu bar shows cumulative progress across backup phases, not just
  # the current phase. FractionOfProgressBar is the fraction of the total
  # progress bar that the current phase occupies; earlier phases (scanning,
  # preparing) already filled (1 - FractionOfProgressBar) of it. Percent is
  # progress *within* the current phase (a 0-1 fraction, nested in the
  # Progress sub-dictionary). So overall:
  #   (1 - FractionOfProgressBar) + FractionOfProgressBar * Percent
  # Both values are quoted fractions. Default FractionOfProgressBar to 1 so
  # the formula degrades to the raw Percent if the key is ever absent.
  percent="$(printf '%s\n' "$status" | awk -F'"' '
    BEGIN { frac = 1 }
    /[[:space:]]FractionOfProgressBar = / { frac = $2 }
    /[[:space:]]Percent = / { pct = $2 }
    END { printf "%d", ((1 - frac) + frac * pct) * 100 + 0.5 }
  ')"
  printf 'percent\t%s\n' "${percent:-0}"
else
  printf 'running\t0\n'
fi