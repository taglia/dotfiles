-- VPN status indicator.
-- Shows a compact "VPN" marker on the right. Bright green means connected; gray
-- means disconnected. Click for details. Tailscale gets special handling for
-- exit-node status when the `tailscale` CLI is present.

local vpn = SBAR.add("item", "vpn", {
	position = "right",
	-- VPN state changes rarely and the poll shells out to scutil (and possibly
	-- tailscale), so a slow tick is enough; system_woke and clicks refresh it
	-- at the moments it actually changes.
	update_freq = 60,
	icon = {
		string = "VPN",
		font = { family = "Hack Nerd Font", style = "Bold", size = DEFAULT_ITEM.icon.font.size * 0.82 },
		padding_left = DEFAULT_ITEM.icon.padding_left,
		padding_right = DEFAULT_ITEM.icon.padding_right,
	},
	label = { drawing = false },
	background = {
		drawing = true,
		color = COLORS.mocha_mantle,
		border_color = COLORS.mocha_overlay_1,
	},
	popup = { align = "right" },
})

local rows = {}
for i = 1, 3 do
	rows[i] = SBAR.add("item", "vpn.detail." .. i, {
		position = "popup." .. vpn.name,
		icon = { drawing = false },
		label = {
			string = "",
			font = { family = "Hack Nerd Font", style = "Regular", size = 14.0 },
			align = "left",
			width = 250,
			padding_left = 14,
			padding_right = 14,
		},
		drawing = false,
	})
end

local vpn_popup_open = false
local last_details = { "VPN: disconnected" }

local function set_rows(details)
	for i = 1, #rows do
		if details[i] then
			rows[i]:set({ label = { string = details[i] }, drawing = true })
		else
			rows[i]:set({ drawing = false })
		end
	end
end

local function update_vpn()
	local cmd = [[
connected_name=$(scutil --nc list 2>/dev/null | awk -F'"' '/\(Connected\)/ {print $2; exit}')
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
    ts=$(command -v tailscale)
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
  "$ts" status --json 2>/dev/null | /usr/bin/python3 -c '
import json, sys
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(0)
st=d.get("BackendState") or ""
print("tailscale\t" + st)
exit_status=d.get("ExitNodeStatus")
if exit_status:
    peer_id=exit_status.get("ID") or exit_status.get("ExitNodeID") or ""
    peers=d.get("Peer") or {}
    peer=peers.get(peer_id, {}) if peer_id else {}
    if not peer and peer_id:
        for p in peers.values():
            if p.get("ID") == peer_id:
                peer=p
                break

    loc=peer.get("Location") or {}
    city=loc.get("City") or peer.get("City") or ""
    country=loc.get("Country") or peer.get("Country") or ""
    if country:
        name=country
    elif city:
        name=city
    else:
        name=peer.get("HostName") or peer.get("DNSName") or peer_id or "selected"

    online=exit_status.get("Online")
    if online is False:
        print("exit\t" + name + " (offline)")
    else:
        print("exit\t" + name)
else:
    print("exit\tNone")
'
fi
]]
	SBAR.exec(cmd, function(out)
		local values = {}
		for line in (out or ""):gmatch("[^\r\n]+") do
			local key, value = line:match("([^\t]+)\t(.+)")
			if key and value then
				values[key] = value
			end
		end

		local connected = values.status == "connected"
		local name = values.name or (connected and "Connected" or "Disconnected")
		last_details = { "VPN: " .. name }
		if values.tailscale and values.tailscale ~= "" then
			table.insert(last_details, "Tailscale: " .. values.tailscale)
		end
		if values.exit and values.exit ~= "" then
			table.insert(last_details, "Exit node: " .. values.exit)
		end

		vpn:set({
			icon = { color = connected and COLORS.mocha_green or COLORS.mocha_overlay_1 },
			background = {
				color = COLORS.mocha_mantle,
				border_color = connected and COLORS.mocha_green or COLORS.mocha_overlay_1,
			},
		})

		if vpn_popup_open then
			set_rows(last_details)
		end
	end)
end

vpn:subscribe({ "routine", "system_woke" }, update_vpn)

vpn:subscribe("mouse.clicked", function()
	vpn_popup_open = not vpn_popup_open
	vpn:set({ popup = { drawing = vpn_popup_open } })
	if vpn_popup_open then
		set_rows(last_details)
		update_vpn()
	end
end)

update_vpn()

