#!/usr/bin/env python3
# Tailscale status parser for helpers/vpn-status.sh.
#
# Reads a `tailscale status --json` document from stdin and prints the two
# extra tab-separated lines vpn.lua consumes when the connected VPN service is
# Tailscale:
#   tailscale<TAB><BackendState>
#   exit<TAB><exit node name, "(offline)" suffix, or None>
#
# Resolves the exit node to a human-readable name (country -> city -> host) by
# walking the Peer map. Any parse failure is swallowed (exit 0) so a malformed
# status document never breaks the bar.
import json
import sys

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

st = d.get("BackendState") or ""
print("tailscale\t" + st)

exit_status = d.get("ExitNodeStatus")
if not exit_status:
    print("exit\tNone")
    sys.exit(0)

peer_id = exit_status.get("ID") or exit_status.get("ExitNodeID") or ""
peers = d.get("Peer") or {}

peer = peers.get(peer_id, {}) if peer_id else {}
if not peer and peer_id:
    for p in peers.values():
        if p.get("ID") == peer_id:
            peer = p
            break

loc = peer.get("Location") or {}
city = loc.get("City") or peer.get("City") or ""
country = loc.get("Country") or peer.get("Country") or ""

if country:
    name = country
elif city:
    name = city
else:
    name = peer.get("HostName") or peer.get("DNSName") or peer_id or "selected"

online = exit_status.get("Online")
if online is False:
    print("exit\t" + name + " (offline)")
else:
    print("exit\t" + name)