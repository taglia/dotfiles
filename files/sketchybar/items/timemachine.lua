-- Time Machine indicator.
-- Built by utils.make_status_item (shared with items/ccc.lua): hidden unless
-- a destination backup is in progress, hover shows the backup progress
-- percentage. The status probe lives in helpers/timemachine-status.sh.

local utils = require("utils")

utils.make_status_item({
  name = "timemachine",
  -- Circular-arrow glyph reminiscent of the Time Machine menubar icon
  -- (green, per macOS). Adjust if your Nerd Font build lacks it.
  icon = "󰑐",
  icon_color = COLORS.mocha_green,
  script = "timemachine-status.sh",
  initial_status = "0%",
  -- Keep showing the last known percentage when a tick omits it.
  status = function(values)
    return values.percent and (values.percent .. "%")
  end,
})
