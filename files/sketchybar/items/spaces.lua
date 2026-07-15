-- AeroSpace workspace indicator.
--
-- No macOS Spaces and no `rift` — workspaces come entirely from AeroSpace.
-- `aerospace.toml` runs, on every workspace change:
--   <sketchybar> --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE
-- (configured in modules/darwin/aerospace.nix, using the absolute nix store
-- path to sketchybar because aerospace's launchd daemon does not have the
-- Home Manager user PATH). We create one item per workspace on the left and
-- highlight the focused one. On every workspace-change event we RE-QUERY
-- `aerospace list-workspaces --focused` (the source of truth, robust on
-- multi-monitor setups) rather than trusting env.FOCUSED_WORKSPACE alone.
-- `aerospace` is on the wrapper's PATH via programs.sketchybar.extraPackages.

local WORKSPACES = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }

-- Per-workspace icons. Only the active workspace shows its icon.
local WORKSPACE_ICONS = {
	["1"] = "󰖟", -- browser / web
	["2"] = "󰇮", -- mail
	["3"] = "󰇮", -- mail
	["4"] = "󰭹", -- chat
	["5"] = "", -- terminal
	["6"] = "󰈔", -- file
	["7"] = "󰈔", -- file
	["8"] = "󰈔", -- file
	["9"] = "󰈔", -- file
}

SBAR.add("event", "aerospace_workspace_change")

local spaces = {}

local function highlight(focused)
	focused = focused and focused:gsub("%s+", "") or nil
	for _, entry in ipairs(spaces) do
		local is_focused = (focused == entry.sid)
		local workspace_icon = WORKSPACE_ICONS[entry.sid]
		entry.item:set({
			icon = { color = is_focused and COLORS.black or COLORS.mocha_text },
			label = {
				string = workspace_icon or "",
				color = is_focused and COLORS.black or COLORS.mocha_text,
				drawing = is_focused and workspace_icon ~= nil,
			},
			background = { drawing = is_focused },
		})

		-- Small slide-in/slide-out effect for the active workspace's icon.
		-- SketchyBar animates the label width; drawing is toggled above so the icon
		-- does not reserve space on inactive workspaces.
		SBAR.animate("tanh", 18.0, function()
			entry.item:set({ label = { width = (is_focused and workspace_icon ~= nil) and 22 or 0 } })
		end)
	end
end

for _, sid in ipairs(WORKSPACES) do
	local space = SBAR.add("item", "space." .. sid, {
		position = "left",
		icon = {
			string = sid,
			font = { family = "Hack Nerd Font", style = "Bold", size = 18.0 },
			color = COLORS.mocha_text,
			padding_left = 9,
			padding_right = 9,
		},
		label = {
			drawing = false,
			width = 0,
			font = { family = "Hack Nerd Font", style = "Bold", size = 17.0 },
			padding_left = 0,
			padding_right = 9,
		},
		background = {
			color = COLORS.mocha_yellow,
			border_color = COLORS.mocha_yellow,
			border_width = 1,
			corner_radius = 10,
			height = 32,
			drawing = false,
		},
		click_script = "aerospace workspace " .. sid,
	})
	table.insert(spaces, { item = space, sid = sid })
end

-- One subscription (on the first space item) handles all workspace-change
-- events: re-query the actual focused workspace and highlight accordingly.
spaces[1].item:subscribe("aerospace_workspace_change", function()
	SBAR.exec("aerospace list-workspaces --focused", highlight)
end)

-- Best-effort initial highlight at load.
SBAR.exec("aerospace list-workspaces --focused", highlight)

