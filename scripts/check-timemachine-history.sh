#!/usr/bin/env bash
# macOS integration fixtures for the native plist history reader.
set -eu
root="$(cd "$(dirname "$0")/.." && pwd)"
helper="$root/files/sketchybar/helpers/timemachine-history.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/history.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict><key>Destinations</key><array>
<dict><key>LastKnownVolumeName</key><string>Disk &amp; One</string>
<key>SnapshotDates</key><array>
<date>2026-01-01T01:00:00Z</date><date>2026-01-05T01:00:00Z</date>
<date>2026-01-02T01:00:00Z</date><date>2026-01-06T01:00:00Z</date>
<date>2026-01-04T01:00:00Z</date><date>2026-01-03T01:00:00Z</date>
</array>
<key>AttemptDates</key><array><date>2026-02-01T01:00:00Z</date></array>
<key>ReferenceLocalSnapshotDate</key><date>2026-03-01T01:00:00Z</date>
</dict>
<dict><key>LastKnownVolumeName</key><string>Disk Two</string>
<key>SnapshotDates</key><array><date>2026-01-07T01:00:00Z</date></array></dict>
<dict><key>LastKnownVolumeName</key><string>New disk</string></dict>
</array></dict></plist>
PLIST
out="$(bash "$helper" "$tmp/history.plist")"
[[ "$(printf '%s\n' "$out" | grep -c $'^backup_[1-5]\t')" == 5 ]]
for i in 1 2 3 4 5; do
  day=$((8 - i))
  epoch="$(TZ=UTC /bin/date -j -f '%Y-%m-%dT%H:%M:%SZ' "2026-01-0${day}T01:00:00Z" '+%s')"
  printf '%s\n' "$out" | grep -Fx "$(printf 'backup_%d\t%s' "$i" "$epoch")" >/dev/null
done
printf '%s\n' "$out" | grep -Fx $'last_destination\tDisk Two' >/dev/null
printf '%s\n' "$out" | grep -Fx $'backup_destination_2\tDisk & One' >/dev/null
printf 'PASS newest five across destinations; ignore attempts/local snapshots; decode names\n'
/usr/libexec/PlistBuddy -c 'Delete :Destinations' -c 'Add :Destinations array' "$tmp/history.plist"
[[ "$(bash "$helper" "$tmp/history.plist")" == $'history\tok\ndestination\tNot configured' ]]
printf 'PASS no configured destinations\n'
if bash "$helper" "$tmp/missing.plist" > "$tmp/out" 2> "$tmp/err"; then
  printf 'FAIL missing file succeeded\n' >&2
  exit 1
fi
grep -q 'Cannot read Time Machine preferences' "$tmp/err"
printf 'PASS read failures report errors and fail\n'
