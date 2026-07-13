-- VPN status indicator.
-- Shows a compact "VPN" marker on the right. Bright green means a VPN-looking
-- connection is active; gray means none detected. Uses macOS VPN services first
-- (`scutil --nc list`) and falls back to utun interfaces, which many VPNs use.

local vpn = SBAR.add("item", "vpn", {
	position = "right",
	update_freq = 10,
	icon = {
		string = "VPN",
		font = { family = "Hack Nerd Font", style = "Bold", size = DEFAULT_ITEM.icon.font.size * 0.82 },
		padding_left = DEFAULT_ITEM.icon.padding_left,
		padding_right = DEFAULT_ITEM.icon.padding_right,
	},
	label = { drawing = false },
	background = {
		drawing = true,
		color = COLORS.background,
		border_color = COLORS.background_border,
	},
})

local function update_vpn()
	local cmd = [[
if scutil --nc list 2>/dev/null | grep -q '(Connected)'; then
  echo connected
elif ifconfig 2>/dev/null | awk '/^utun[0-9]+:/{iface=$1; sub(":","",iface)} /status: active/{if (iface) print iface}' | grep -q .; then
  echo connected
else
  echo disconnected
fi
]]
	SBAR.exec(cmd, function(out)
		local status = (out or ""):gsub("%s+", "")
		local connected = status == "connected"
		vpn:set({
			icon = { color = connected and 0xff22c55e or COLORS.disabled_color },
			background = {
				color = connected and 0xff064e3b or COLORS.background,
				border_color = connected and 0xff22c55e or COLORS.background_border,
			},
		})
	end)
end

vpn:subscribe({ "routine", "system_woke" }, update_vpn)
update_vpn()