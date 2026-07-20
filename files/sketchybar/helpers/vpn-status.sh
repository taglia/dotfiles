#!/usr/bin/env bash
# VPN status probe for items/vpn.lua.
#
# Prints tab-separated lines consumed by vpn.lua:
#   status<TAB>connected|disconnected
#   name<TAB><VPN service name>      (connected) or "Disconnected"
#   tailscale<TAB><BackendState>     (only when the connected VPN is Tailscale)
#   exit<TAB><exit node or None>     (only when the connected VPN is Tailscale)
#
# Kept in helpers/ (rather than inlined in vpn.lua) so it can be shellcheck-ed
# by the CI check. The Tailscale JSON parsing lives in tailscale-exit-node.py,
# resolved relative to this file so it works wherever the config is installed.
set -u

script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"

connected_name="$(scutil --nc list 2>/dev/null | awk -F'"' '/\(Connected\)/ {print $2; exit}')"
if [ -n "$connected_name" ]; then
  printf 'status\tconnected\n'
  printf 'name\t%s\n' "$connected_name"
else
  printf 'status\tdisconnected\n'
  printf 'name\tDisconnected\n'
fi

# Do not use generic utun interfaces for VPN detection: Tailscale and other
# network extensions can leave utun devices around after disconnecting. Only
# show Tailscale-specific details when macOS reports the connected VPN service
# as Tailscale.
if [ "$connected_name" = "Tailscale" ]; then
  if command -v tailscale >/dev/null 2>&1; then
    ts="$(command -v tailscale)"
  elif [ -x /usr/local/bin/tailscale ]; then
    ts=/usr/local/bin/tailscale
  else
    ts=
  fi
else
  ts=
fi

# Guard the python3 call: on a machine without the Xcode Command Line Tools
# the /usr/bin/python3 shim would pop the "install developer tools" dialog.
if [ -n "$ts" ] && [ -x /usr/bin/python3 ] && xcode-select -p >/dev/null 2>&1; then
  "$ts" status --json 2>/dev/null | /usr/bin/python3 "$script_dir/tailscale-exit-node.py"
fi