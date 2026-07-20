local border_width = 1
local corner_radius = 10
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
    color = COLORS.mocha_text,
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
    color = COLORS.mocha_text,
    padding_right = item_padding,
  },
  background = {
    color = COLORS.black,
    border_color = COLORS.mocha_overlay_2,
    border_width = border_width,
    corner_radius = corner_radius,
    height = item_height,
  },
  popup = {
    background = {
      corner_radius = corner_radius,
      color = COLORS.black,
      border_width = border_width,
      border_color = COLORS.mocha_text,
    },
  },
}

SBAR.default(default_item)
-- Must stay a SEPARATE call after the one above: setting background.color
-- auto-enables background.drawing, and within a single table the key order
-- is pairs() order (random), so an inline drawing=false could be applied
-- before color and get re-enabled. Items opt in to a visible background
-- themselves (e.g. the VPN pill).
SBAR.default({ background = { drawing = false } })
-- Add Bar
-- nix adaptation: explicitly enable drawing. Under the Home Manager wrapper
-- the bar otherwise loaded with drawing=off (invisible); forcing it on here
-- survives reloads/restarts.
SBAR.bar({
  -- position = "top",
  height = bar_height,
  color = COLORS.black,
  blur_radius = 0,
  drawing = true,
})

return default_item
