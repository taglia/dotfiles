#!/usr/bin/env bash
# Next-DST-transition probe for items/calendar.lua (world-clock popup).
#
# DST rules differ worldwide (EU vs US vs none); we report Italy's next
# transition (Europe/Rome follows the EU rules used in Italy). Prints exactly
# one line:
#   Next DST change: <weekday> <mon> <day> · ±Nh
# or, when no offset change is found within a year:
#   Next DST change: none within a year
#
# Uses macOS (BSD) `date -j` only.
set -u

tz=Europe/Rome
today=$(date +%Y-%m-%d)
base=$(TZ=$tz date -j -f "%Y-%m-%d" "$today" +%z)

# Scan up to a year ahead for the first day whose UTC offset differs from
# today's.
found_date=""
found_off=""
for i in $(seq 0 366); do
  d=$(date -j -v+"${i}"d -f "%Y-%m-%d" "$today" +%Y-%m-%d)
  off=$(TZ=$tz date -j -f "%Y-%m-%d" "$d" +%z)
  if [ "$off" != "$base" ]; then
    found_date=$d
    found_off=$off
    break
  fi
done

if [ -z "$found_date" ]; then
  printf "Next DST change: none within a year\n"
  exit 0
fi

# Keep only the signed hour component of each +HHMM offset (all EU offsets
# are whole hours). printf %d parses "+01"/"-05" as a plain signed decimal,
# avoiding both sed and the octal pitfall of $((+0N)).
bh=$(printf '%d' "${base:0:3}")
oh=$(printf '%d' "${found_off:0:3}")
diff=$((oh - bh))
if [ "$diff" -lt 0 ]; then
  dir="−$((-diff))h"
else
  dir="+${diff}h"
fi
wd=$(TZ=$tz date -j -f "%Y-%m-%d" "$found_date" +"%a %b %d")
printf "Next DST change: %s · %s\n" "$wd" "$dir"