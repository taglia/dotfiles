-- Carbon Copy Cloner indicator.
-- Built by utils.make_status_item (shared with items/timemachine.lua): hidden
-- unless a CCC task is running, hover shows the task progress. The label is
-- the percentage, or the current phase when CCC reports indeterminate
-- progress. The status probe lives in helpers/ccc-status.sh.

local utils = require("utils")

utils.make_status_item({
  name = "ccc",
  -- Clone/copy glyph. Adjust if your Nerd Font build lacks it.
  icon = "󰒋",
  icon_color = COLORS.mocha_blue,
  script = "ccc-status.sh",
  initial_status = "…",
  status = function(values)
    if values.percent and values.percent ~= "-1" then
      return values.percent .. "%"
    elseif values.phase and values.phase ~= "" then
      return values.phase
    end
    return "…"
  end,
})
