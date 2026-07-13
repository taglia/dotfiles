local border_width = 1
local corner_raduis = 10
local item_padding = 13
local bar_height = 38
local item_height = 32
local size = 18.0

-- Define default item properties
local default_item = {
	-- always the left object
	icon = {
		font = {
			family = "Hack Nerd Font",
			size = size,
		},
		color = COLORS.accent_color,
		padding_left = item_padding,
		padding_right = item_padding,
		y_offset = 0,
	},
	-- always the right object
	label = {
		font = {
			family = "Hack Nerd Font",
			style = "Semibold",
			size = size,
		},
		color = COLORS.accent_color,
		padding_right = item_padding,
	},
	background = {
		color = COLORS.background,
		border_color = COLORS.background_border,
		border_width = border_width,
		corner_radius = corner_raduis,
		height = item_height,
	},
	popup = {
		background = {
			corner_radius = corner_raduis,
			color = COLORS.popup_background,
			border_width = border_width,
			border_color = COLORS.popup_border,
		},
	},
}

SBAR.default(default_item)
SBAR.default({ background = { drawing = false } })
-- Add Bar
-- nix adaptation: explicitly enable drawing. Under the Home Manager wrapper
-- the bar otherwise loaded with drawing=off (invisible); forcing it on here
-- survives reloads/restarts.
SBAR.bar({
	-- position = "top",
	height = bar_height,
	color = COLORS.bar_color,
	blur_radius = 0,
	drawing = true,
})

return default_item