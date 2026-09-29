#!/usr/bin/env bash
# Network probe regression tests; no actual adapters or permission prompts.
set -euo pipefail
cd "$(dirname "$0")/.."

mock_networksetup() {
  printf '%s\n' 'Hardware Port: Wi-Fi' 'Device: en0' \
    'Hardware Port: USB Ethernet' 'Device: en7' \
    'Hardware Port: Thunderbolt Bridge' 'Device: bridge0'
}
mock_ifconfig() {
  case "$1" in
    en0) printf 'status: %s\n' "$WIFI_LINK" ;;
    en7) printf 'status: %s\n' "$WIRED_LINK" ;;
    *) echo 'Unexpected interface' >&2; return 1 ;;
  esac
}
mock_unredactor() {
  # Upstream accepts no custom status flag. Fail before returning an SSID if
  # the probe accidentally reintroduces one (even though probe errors are caught).
  [[ $# -eq 0 ]] || return 1
  printf '%s\n' "$APP_RESULT"
}
export -f mock_networksetup mock_ifconfig mock_unredactor
export WIFI_UNREDACTOR=mock_unredactor
export WIFI_LINK=active WIRED_LINK=inactive APP_RESULT='{"ssid":"Home"}'

# Replace only the two absolute macOS probe commands in the test copy.
source_text=$(< files/sketchybar/helpers/network-status.sh)
source_text=${source_text//\/usr\/sbin\/networksetup/mock_networksetup}
source_text=${source_text//\/sbin\/ifconfig/mock_ifconfig}
check() {
  bash -c "$source_text" | jq -e "$1" >/dev/null
}
check '.status == "connected" and .ssid == "Home" and .wired == false'
WIRED_LINK=active
check '.status == "connected" and .wired == true'
APP_RESULT='{"error":"location services denied"}'
check '.status == "connected" and .ssid == "" and (.reason | contains("Location Services"))'
APP_RESULT='{"ssid":"failed to retrieve SSID"}'
check '.ssid == "" and .status == "connected"'
APP_RESULT='not json'
check '.ssid == "" and .status == "connected"'
APP_RESULT='{"ssid":"quoted \" name 🎉"}'
check '.ssid == "quoted \" name 🎉"'
WIFI_LINK=inactive
check '.status == "disconnected" and .wired == true and .ssid == ""'
WIRED_LINK=inactive
check '.status == "disconnected" and .wired == false'
WIFI_LINK=unknown
check '.status == "unknown"'
printf 'SketchyBar network probe checks passed\n'
