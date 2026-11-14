#!/bin/sh
# Battery levels macOS itself tracks for Bluetooth HID devices (Magic
# Keyboard/Trackpad/Mouse and similar), read from the IO registry. These are
# not in `system_profiler SPBluetoothDataType`, which only carries levels for
# audio devices, and need no AirBuddy or automation permission.
# Output: Bluetooth address<TAB>NN%, one device per line (same shape as
# airbuddy-batteries.applescript). Devices without a percentage are skipped.
set -eu

/usr/sbin/ioreg -r -c AppleDeviceManagementHIDEventService -l 2>/dev/null | awk '
  function flush() {
    if (addr != "" && pct ~ /^[0-9]+$/ && pct <= 100) printf "%s\t%s%%\n", addr, pct
    addr = ""; pct = ""
  }
  /^[ |]*\+-o / { flush() }
  /"DeviceAddress" = "/ { sub(/.*"DeviceAddress" = "/, ""); sub(/".*/, ""); addr = $0 }
  /"BatteryPercent" = / { sub(/.*"BatteryPercent" = /, ""); pct = $0 + 0 }
  END { flush() }
'
