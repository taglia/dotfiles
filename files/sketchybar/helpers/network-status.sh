#!/usr/bin/env bash
# Installed as sketchybar-network-status by modules/home/sketchybar.nix, which
# supplies jq on PATH and WIFI_UNREDACTOR (the pinned app's executable).
set -euo pipefail
export LC_ALL=C

hardware=$(/usr/sbin/networksetup -listallhardwareports)
wifi_device=$(printf '%s\n' "$hardware" | awk '
  /^Hardware Port:/ { wifi = ($0 == "Hardware Port: Wi-Fi" || $0 == "Hardware Port: AirPort") }
  wifi && /^Device:/ { print $2; exit }
')
# Only hardware Ethernet/Thunderbolt interfaces, not VPNs, bridges, or awdl.
# Link status means a cable/link is active, not necessarily Internet access.
wired=false
while IFS= read -r device; do
  if /sbin/ifconfig "$device" 2>/dev/null | grep -q 'status: active'; then
    wired=true
  fi
done < <(printf '%s\n' "$hardware" | awk '
  /^Hardware Port:/ { wifi = ($0 == "Hardware Port: Wi-Fi" || $0 == "Hardware Port: AirPort") }
  !wifi && /^Device: en[0-9]+$/ { print $2 }
')

status=unknown
ssid=''
reason='Wi-Fi status unavailable'
if [[ -z "$wifi_device" ]]; then
  status=disconnected
  reason='No Wi-Fi interface'
else
  # Association/link state does not require DHCP or permission to read the SSID.
  link=$(/sbin/ifconfig "$wifi_device" 2>/dev/null || true)
  if grep -q 'status: active' <<< "$link"; then
    status=connected
    result=$("${WIFI_UNREDACTOR:?}" --status 2>/dev/null || true)
    # Upstream encodes missing SSIDs as this sentinel, not null.
    ssid=$(printf '%s' "$result" | jq -r '
      if (.ssid | type) == "string" and .ssid != "failed to retrieve SSID"
      then .ssid else "" end' 2>/dev/null || true)
    reason='Connected — SSID unavailable; enable wifi-unredactor in Location Services'
  elif grep -q 'status: inactive' <<< "$link"; then
    status=disconnected
    reason='Wi-Fi disconnected'
  fi
fi
jq -cn --arg status "$status" --arg ssid "$ssid" --arg reason "$reason" \
  --argjson wired "$wired" '{status: $status, ssid: $ssid, reason: $reason, wired: $wired}'
