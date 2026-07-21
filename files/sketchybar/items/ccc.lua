-- Carbon Copy Cloner indicator.
-- Hidden entirely unless a CCC task is running (its only purpose is
-- answering "is it safe to unplug the laptop?"). While visible, hovering
-- shows the task progress (percentage, or the current phase when CCC reports
-- indeterminate progress), mirroring the battery indicator's hover behavior.
--
-- The status probe lives in helpers/ccc-status.sh (shellcheck-ed by CI) so
-- this file just parses its tab-separated output. The helper path is
-- resolved relative to this file's own location, so it works wherever the
-- config tree is installed (the HM wrapper copies the directory verbatim
-- into ~/.config/sketchybar/).

local ccc = SBAR.add("item", "ccc", {
  position = "right",
  -- Backups last minutes to hours; a moderate tick is plenty. The icon is
  -- hidden when idle, so the only cost of the poll is the helper script.
  update_freq = 30,
  drawing = false,
  icon = {
    -- Clone/copy glyph. Adjust if your Nerd Font build lacks it.
    string = "󰒋",
    color = COLORS.mocha_blue,
    font = { family = "Hack Nerd Font", style = "Regular" },
  },
  label = { drawing = false }, -- Shown on hover only
})

local source = debug.getinfo(1, "S").source
local this_file = source:sub(1, 1) == "@" and source:sub(2) or source
local config_dir = this_file:match("^(.*)/items/[^/]+$") or (os.getenv("HOME") .. "/.config/sketchybar")
local ccc_status_script = config_dir .. "/helpers/ccc-status.sh"

local last_status = "…"

local function ccc_update()
  SBAR.exec("bash '" .. ccc_status_script .. "'", function(out)
    local running = false
    local percent = "-1"
    local phase = nil
    for line in (out or ""):gmatch("[^\r\n]+") do
      local key, value = line:match("([^\t]+)\t(.+)")
      if key == "running" then
        running = value == "1"
      elseif key == "percent" then
        percent = value
      elseif key == "phase" then
        phase = value
      end
    end

    if percent ~= "-1" then
      last_status = percent .. "%"
    elseif phase and phase ~= "" then
      last_status = phase
    else
      last_status = "…"
    end

    ccc:set({
      drawing = running,
      label = { string = last_status, drawing = false },
      icon = { padding_right = DEFAULT_ITEM.icon.padding_right },
    })
  end)
end

-- Show progress when hovering, hide when leaving (same as battery.lua).
ccc:subscribe("mouse.entered", function()
  ccc:set({
    icon = { padding_right = DEFAULT_ITEM.icon.padding_right * 0.5 },
    label = { string = last_status, drawing = true },
  })
end)

ccc:subscribe("mouse.exited", function()
  ccc:set({
    icon = { padding_right = DEFAULT_ITEM.icon.padding_right },
    label = { drawing = false },
  })
end)

ccc:subscribe({ "routine", "system_woke" }, ccc_update)

-- Populate immediately instead of waiting up to update_freq for the first
-- routine tick.
ccc_update()
