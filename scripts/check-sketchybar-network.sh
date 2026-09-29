#!/usr/bin/env bash
# Network probe regression tests; no actual adapters or permission prompts.
set -euo pipefail
cd "$(dirname "$0")/.."

mock_networksetup() {
  printf '%s\n' 'Hardware Port: Wi-Fi' 'Device: en0' \
    'Hardware Port: USB Ethernet' 'Device: en7' \
    'Hardware Port: USB Ethernet 2' 'Device: en8' \
    'Hardware Port: Thunderbolt Bridge' 'Device: bridge0'
}
mock_ifconfig() {
  case "$1" in
    en0)
      printf 'status: %s\ninet6 fe80::1234 prefixlen 64\n' "$WIFI_LINK"
      [[ -z "$WIFI_IP" ]] || printf 'inet %s netmask 0xffffff00\n' "$WIFI_IP"
      ;;
    en7)
      printf 'status: %s\nmedia: %s\n' "$WIRED_LINK" "$WIRED_MEDIA"
      [[ -z "$WIRED_IP" ]] || printf 'inet %s netmask 0xffffff00\n' "$WIRED_IP"
      ;;
    en8) printf 'status: %s\nmedia: 10Gbase-T <full-duplex>\ninet 10.0.0.2\n' "$SECOND_LINK" ;;
    *) echo 'Unexpected interface' >&2; return 1 ;;
  esac
}
mock_route() {
  # Fail on unscoped lookups: those could return a VPN/other adapter's gateway.
  [[ $# -eq 6 && "$1 $2 $3 $4" == '-n get -inet -ifscope' && "$6" == default ]] || return 1
  case "$5" in
    en0) printf 'gateway: %s\ninterface: %s\n' "$WIFI_GATEWAY" "$WIFI_ROUTE_INTERFACE" ;;
    en7) printf 'gateway: %s\ninterface: en7\n' "$WIRED_GATEWAY" ;;
    en8) printf 'gateway: 10.0.0.1\ninterface: en8\n' ;;
    *) return 1 ;;
  esac
}
mock_unredactor() {
  # Upstream accepts no custom status flag. Fail before returning an SSID if
  # the probe accidentally reintroduces one (even though probe errors are caught).
  [[ $# -eq 0 ]] || return 1
  printf '%s\n' "$APP_RESULT"
}
export -f mock_networksetup mock_ifconfig mock_route mock_unredactor
export WIFI_UNREDACTOR=mock_unredactor
export WIFI_LINK=active WIRED_LINK=inactive SECOND_LINK=inactive APP_RESULT='{"ssid":"Home"}'
export WIFI_IP=192.168.1.20 WIFI_GATEWAY=192.168.1.1 WIFI_ROUTE_INTERFACE=en0
export WIRED_IP=192.168.2.20 WIRED_GATEWAY=192.168.2.1
export WIRED_MEDIA='autoselect (2500base-T <full-duplex>)'

# Replace only the absolute macOS probe commands in the test copy.
source_text=$(< files/sketchybar/helpers/network-status.sh)
source_text=${source_text//\/usr\/sbin\/networksetup/mock_networksetup}
source_text=${source_text//\/sbin\/ifconfig/mock_ifconfig}
source_text=${source_text//\/sbin\/route/mock_route}
check() {
  bash -c "$source_text" | jq -e "$1" >/dev/null
}
check '.status == "connected" and .ssid == "Home" and .wired == false and .wired_links == []'
check '.wifi_ip == "192.168.1.20" and .wifi_gateway == "192.168.1.1"'
WIRED_LINK=active
check '.status == "connected" and .wired == true'
check '.wired_links == [{interface:"en7", ip:"192.168.2.20", gateway:"192.168.2.1", speed:"2.5 Gbps"}]'
for pair in '100baseTX=100 Mbps' '1000baseT=1 Gbps' '2.5Gbase-T=2.5 Gbps' '5000base-T=5 Gbps' '10Gbase-T=10 Gbps'; do
  WIRED_MEDIA="autoselect (${pair%%=*} <full-duplex>)"
  check ".wired_links[0].speed == \"${pair#*=}\""
done
# Prefer negotiated media over the configured medium.
WIRED_MEDIA='1000baseT (100baseTX <full-duplex>)'
check '.wired_links[0].speed == "100 Mbps"'
WIRED_MEDIA=autoselect
check '.wired_links[0].speed == ""'
SECOND_LINK=active
check '(.wired_links | length) == 2 and .wired_links[1] == {interface:"en8", ip:"10.0.0.2", gateway:"10.0.0.1", speed:"10 Gbps"}'
SECOND_LINK=inactive
# Missing IPv4, missing/non-IP gateways, and scope mismatches remain unavailable.
WIFI_IP='' WIRED_IP='' WIRED_GATEWAY=''
check '.wifi_ip == "" and .wired_links[0].ip == "" and .wired_links[0].gateway == ""'
WIFI_GATEWAY='link#4'
check '.wifi_gateway == ""'
WIFI_GATEWAY=10.0.0.1 WIFI_ROUTE_INTERFACE=utun4
check '.wifi_gateway == ""'
APP_RESULT='{"error":"location services denied"}'
check '.status == "connected" and .ssid == "" and (.reason | contains("Location Services"))'
APP_RESULT='{"ssid":"failed to retrieve SSID"}'
check '.ssid == "" and .status == "connected"'
APP_RESULT='not json'
check '.ssid == "" and .status == "connected"'
APP_RESULT='{"ssid":"quoted \" name 🎉"}'
check '.ssid == "quoted \" name 🎉"'
WIFI_LINK=inactive
check '.status == "disconnected" and .wired == true and .ssid == "" and .wifi_ip == "" and .wifi_gateway == ""'
WIRED_LINK=inactive
check '.status == "disconnected" and .wired == false and .wired_links == []'
WIFI_LINK=unknown
check '.status == "unknown"'
printf 'SketchyBar network probe checks passed\n'
