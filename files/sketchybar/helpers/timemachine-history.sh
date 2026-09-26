#!/usr/bin/env bash
# Local destination backup history, without mounting disks or requiring root.
# Optional plist argument supports regression fixtures. Dates are SnapshotDates,
# not AttemptDates or ReferenceLocalSnapshotDate (which are not completed backups).
set -eu
export LC_ALL=C
source_plist="${1:-/Library/Preferences/com.apple.TimeMachine.plist}"
snapshot="$(mktemp)"
trap 'rm -f "$snapshot"' EXIT

fail() {
  printf 'timemachine-history: %s\n' "$1" >&2
  printf 'history\tunavailable\n'
  exit 1
}

# Read the system domain via CFPreferences (cfprefsd), not direct file access:
# macOS can deny a launch agent access to this plist even when Terminal can read it.
if [[ $# == 0 ]]; then
  /usr/bin/defaults export /Library/Preferences/com.apple.TimeMachine - > "$snapshot" || fail 'Cannot read Time Machine preferences via defaults'
else
  /usr/bin/plutil -convert xml1 -o "$snapshot" "$source_plist" || fail 'Cannot read Time Machine preferences'
fi
count="$(/usr/bin/plutil -extract Destinations raw -o - "$snapshot")" || fail 'Cannot read destinations'
[[ "$count" =~ ^[0-9]+$ ]] || fail 'Invalid destination count'

names=""
records=""
for ((i = 0; i < count; i++)); do
  name="$(/usr/bin/plutil -extract "Destinations.$i.LastKnownVolumeName" raw -o - "$snapshot" 2>/dev/null)" || name='Unknown destination'
  name="$(printf '%s' "$name" | tr '\t\r\n' '   ')"
  names="${names:+$names, }$name"
  # Extract a date array once, rather than spawning a process for every snapshot.
  # Missing SnapshotDates is normal for a newly configured destination.
  dates="$(/usr/bin/plutil -extract "Destinations.$i.SnapshotDates" xml1 -o - "$snapshot" 2>/dev/null)" || continue
  dates="$(printf '%s\n' "$dates" | awk -F '[<>]' '/<date>/ { print $3 }' | sort -ru | head -5)"
  while IFS= read -r date; do
    [[ -n "$date" ]] || continue
    epoch="$(TZ=UTC /bin/date -j -f '%Y-%m-%dT%H:%M:%SZ' "$date" '+%s' 2>/dev/null)" || fail 'Invalid snapshot date'
    records="${records}$(printf '%s\t%s' "$epoch" "$name")"$'\n'
  done <<< "$dates"
done

printf 'history\tok\ndestination\t%s\n' "${names:-Not configured}"
# Keep at most five records globally, including each backup destination.
index=0
while IFS=$'\t' read -r epoch name; do
  [[ -n "$epoch" ]] || continue
  index=$((index + 1))
  if ((index == 1)); then
    printf 'last_backup\t%s\nlast_destination\t%s\n' "$epoch" "$name"
  fi
  printf 'backup_%d\t%s\nbackup_destination_%d\t%s\n' "$index" "$epoch" "$index" "$name"
done < <(printf '%s' "$records" | sort -rn -u | head -5)
