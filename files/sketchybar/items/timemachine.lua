-- Time Machine indicator.
-- Hidden entirely unless a destination backup is in progress (its only
-- purpose is answering "is it safe to unplug the laptop?"). While visible,
-- hovering shows the backup progress percentage, mirroring the battery
-- indicator's hover behavior.
--
-- The status probe lives in helpers/timemachine-status.sh (shellcheck-ed by
-- CI) so this file just parses its tab-separated output. The helper path is
-- resolved relative to this file's own location, so it works wherever the
-- config tree is installed (the HM wrapper copies the directory verbatim into
-- ~/.config/sketchybar/).

local timemachine = SBAR.add("item", "timemachine", {
  position = "right",
  -- Backups last minutes to hours; a moderate tick is plenty. The icon is
  -- hidden when idle, so the only cost of the poll is the helper script.
  update_freq = 30,
  drawing = false,
  icon = {
    -- Circular-arrow glyph reminiscent of the Time Machine menubar icon
    -- (green, per macOS). Adjust if your Nerd Font build lacks it.
    string = "󰑐",
    color = COLORS.mocha_green,
    font = { family = "Hack Nerd Font", style = "Regular" },
  },
  label = { drawing = false }, -- Shown on hover only
})

local source = debug.getinfo(1, "S").source
local this_file = source:sub(1, 1) == "@" and source:sub(2) or source
local config_dir = this_file:match("^(.*)/items/[^/]+$") or (os.getenv("HOME") .. "/.config/sketchybar")
local tm_status_script = config_dir .. "/helpers/timemachine-status.sh"

local last_percent = "0"

local function timemachine_update()
  SBAR.exec("bash '" .. tm_status_script .. "'", function(out)
    local running = false
    for line in (out or ""):gmatch("[^\r\n]+") do
      local key, value = line:match("([^\t]+)\t(.+)")
      if key == "running" then
        running = value == "1"
      elseif key == "percent" then
        last_percent = value
      end
    end

    timemachine:set({
      drawing = running,
      label = { string = last_percent .. "%", drawing = false },
      icon = { padding_right = DEFAULT_ITEM.icon.padding_right },
    })
  end)
end

-- Show percentage when hovering, hide when leaving (same as battery.lua).
timemachine:subscribe("mouse.entered", function()
  timemachine:set({
    icon = { padding_right = DEFAULT_ITEM.icon.padding_right * 0.5 },
    label = { string = last_percent .. "%", drawing = true },
  })
end)

timemachine:subscribe("mouse.exited", function()
  timemachine:set({
    icon = { padding_right = DEFAULT_ITEM.icon.padding_right },
    label = { drawing = false },
  })
end)

timemachine:subscribe({ "routine", "system_woke" }, timemachine_update)

-- Populate immediately instead of waiting up to update_freq for the first
-- routine tick.
timemachine_update()
