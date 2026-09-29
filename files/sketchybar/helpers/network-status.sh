#!/usr/bin/env bash
# Installed as sketchybar-network-status by modules/home/sketchybar.nix, which
# supplies jq on PATH and WIFI_UNREDACTOR (the pinned app's executable).
set -euo pipefail
export LC_ALL=C

# Use IPv4 only, and never borrow a gateway from a different interface (VPNs
# can replace the global default route). No scoped default route means unknown.
gateway_for() {
  local route
  route=$(/sbin/route -n get -inet -ifscope "$1" default 2>/dev/null || true)
  awk -v device="$1" '
    $1 == "interface:" { interface = $2 }
    $1 == "gateway:" { gateway = $2 }
    END {
      if (interface == device && gateway ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/)
        print gateway
    }
  ' <<< "$route"
}

ipv4_address() {
  awk '$1 == "inet" { print $2; exit }'
}

link_speed() {
  awk '
    /media:/ {
      media = tolower($0)
      # Parentheses hold the negotiated medium when autoselect is configured.
      if (match(media, /\([^)]*\)/)) media = substr(media, RSTART, RLENGTH)
      if (match(media, /[0-9]+([.][0-9]+)?[gm]?base/)) {
        rate = substr(media, RSTART, RLENGTH)
        sub(/base$/, "", rate)
        mbps = rate + 0
        if (rate ~ /g$/) mbps *= 1000
        if (mbps >= 1000) printf "%g Gbps", mbps / 1000
        else printf "%g Mbps", mbps
      }
      exit
    }
  '
}

hardware=$(/usr/sbin/networksetup -listallhardwareports)
wifi_device=$(printf '%s\n' "$hardware" | awk '
  /^Hardware Port:/ { wifi = ($0 == "Hardware Port: Wi-Fi" || $0 == "Hardware Port: AirPort") }
  wifi && /^Device:/ { print $2; exit }
')
# Only hardware Ethernet/Thunderbolt interfaces, not VPNs, bridges, or awdl.
# Link status means a cable/link is active, not necessarily Internet access.
wired=false
wired_links='[]'
while IFS= read -r device; do
  link=$(/sbin/ifconfig "$device" 2>/dev/null || true)
  if grep -q 'status: active' <<< "$link"; then
    wired=true
    ip=$(ipv4_address <<< "$link")
    gateway=$(gateway_for "$device")
    speed=$(link_speed <<< "$link")
    wired_links=$(jq -cn --argjson links "$wired_links" --arg interface "$device" \
      --arg ip "$ip" --arg gateway "$gateway" --arg speed "$speed" \
      '$links + [{interface: $interface, ip: $ip, gateway: $gateway, speed: $speed}]')
  fi
done < <(printf '%s\n' "$hardware" | awk '
  /^Hardware Port:/ { wifi = ($0 == "Hardware Port: Wi-Fi" || $0 == "Hardware Port: AirPort") }
  !wifi && /^Device: en[0-9]+$/ { print $2 }
')

status=unknown
ssid=''
wifi_ip=''
wifi_gateway=''
reason='Wi-Fi status unavailable'
if [[ -z "$wifi_device" ]]; then
  status=disconnected
  reason='No Wi-Fi interface'
else
  # Association/link state does not require DHCP or permission to read the SSID.
  link=$(/sbin/ifconfig "$wifi_device" 2>/dev/null || true)
  if grep -q 'status: active' <<< "$link"; then
    status=connected
    wifi_ip=$(ipv4_address <<< "$link")
    wifi_gateway=$(gateway_for "$wifi_device")
    result=$("${WIFI_UNREDACTOR:?}" 2>/dev/null || true)
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
  --arg wifi_ip "$wifi_ip" --arg wifi_gateway "$wifi_gateway" \
  --argjson wired "$wired" --argjson wired_links "$wired_links" \
  '{status: $status, ssid: $ssid, reason: $reason, wifi_ip: $wifi_ip,
    wifi_gateway: $wifi_gateway, wired: $wired, wired_links: $wired_links}'
