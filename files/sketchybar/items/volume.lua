local icons = {
	_100 = "􀊩",
	_66 = "􀊧",
	_33 = "􀊥",
	_10 = "􀊡",
	_0 = "􀊣",
}

local volume_icon = SBAR.add("item", "volume_icon", {
	position = "right",
	label = { drawing = false },
	background = { drawing = false },
})

local function set_icon(volume)
	local icon = icons._0
	if volume > 60 then
		icon = icons._100
	elseif volume > 30 then
		icon = icons._66
	elseif volume > 10 then
		icon = icons._33
	elseif volume > 0 then
		icon = icons._10
	end
	volume_icon:set({ icon = icon })
end

volume_icon:subscribe("volume_change", function(env)
	set_icon(tonumber(env.INFO) or 0)
end)

-- Initialize without waiting for the first volume_change event.
SBAR.exec("osascript -e 'output volume of (get volume settings)'", function(out)
	set_icon(tonumber(out) or 0)
end)

-- SoundSource is a menu-bar app. Its docs expose a global Show/Hide keyboard
-- shortcut, but not a reliable command-line "show main window" action. This
-- sends the user's configured SoundSource shortcut: Option+Shift+S.
volume_icon:subscribe("mouse.clicked", function()
	SBAR.exec([[osascript -e 'tell application "System Events" to keystroke "s" using {option down, shift down}']])
end)