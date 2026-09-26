#!/usr/bin/env bash
# Tab-separated Time Machine status for items/timemachine.lua.
# Progress is meaningful only during Copying; never synthesize phase weights.
set -u

if ! status="$(tmutil status 2>/dev/null)"; then
  printf 'running\t0\nphase\tStatus unavailable\n'
  exit 0
fi

printf '%s\n' "$status" | awk '
  / = / {
    key = $1
    value = $0
    sub(/^[^=]*= */, "", value)
    gsub(/[";]/, "", value)
    sub(/[[:space:]]+$/, "", value)
    if (key == "Running") running = value
    if (key == "BackupPhase") phase = value
    if (key == "Percent") percent = value
    if (key == "TimeRemaining") remaining = value
    if (key == "bytes") bytes = value
    if (key == "totalBytes") total = value
  }
  END {
    printf "running\t%d\n", (running == "1")
    if (running != "1") { print "phase\tIdle"; exit }
    printf "phase\t%s\n", (phase != "" ? phase : "Working")
    if (phase == "Copying") {
      if (percent ~ /^[0-9]+([.][0-9]+)?$/ && percent >= 0 && percent <= 1)
        printf "percent\t%d\n", percent * 100 + 0.5
      if (remaining ~ /^[0-9]+([.][0-9]+)?$/ && remaining > 0)
        printf "remaining\t%d\n", remaining + 0.5
      if (bytes ~ /^[0-9]+$/ && total ~ /^[0-9]+$/ && total > 0) {
        printf "bytes\t%s\n", bytes
        printf "total_bytes\t%s\n", total
      }
    }
  }
'
