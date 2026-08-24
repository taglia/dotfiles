-- Shared helpers for the item modules (required as `require("utils")`).
-- Relies on the SBAR/COLORS/DEFAULT_ITEM globals set up by globals.lua, which
-- init.lua requires before any item.

local M = {}

-- Absolute path of the config directory (the directory containing this file).
-- Resolved from this file's own location, so it works wherever the config
-- tree is installed (the HM wrapper copies the directory verbatim into
-- ~/.config/sketchybar/); falls back to the conventional location.
function M.config_dir()
  local source = debug.getinfo(1, "S").source
  local this_file = source:sub(1, 1) == "@" and source:sub(2) or source
  return this_file:match("^(.*)/[^/]+$") or (os.getenv("HOME") .. "/.config/sketchybar")
end

-- Factory for backup-progress indicators (Time Machine, CCC).
-- Hidden entirely unless the backup is running (their only purpose is
-- answering "is it safe to unplug the laptop?"). While visible, hovering
-- shows the progress label, mirroring the battery indicator's hover behavior.
--
-- The status probe is a helpers/*.sh script (shellcheck-ed by CI) whose
-- tab-separated output is parsed here: the `running` key (value "1"/"0")
-- toggles visibility, and all keys are handed to opts.status, which returns
-- the label to show — or nil to keep the previous one.
--
-- opts: name (item name), icon (glyph), icon_color, script (basename under
-- helpers/), initial_status (label before the first probe), status (function
-- values -> label-or-nil).
function M.make_status_item(opts)
  local item = SBAR.add("item", opts.name, {
    position = "right",
    -- Backups last minutes to hours; a moderate tick is plenty. The icon is
    -- hidden when idle, so the only cost of the poll is the helper script.
    update_freq = 30,
    drawing = false,
    icon = {
      string = opts.icon,
      color = opts.icon_color,
      font = { family = "Hack Nerd Font", style = "Regular" },
    },
    label = { drawing = false }, -- Shown on hover only
  })

  local status_script = M.config_dir() .. "/helpers/" .. opts.script
  local last_status = opts.initial_status

  local function update()
    SBAR.exec("bash '" .. status_script .. "'", function(out)
      local running = false
      local values = {}
      for line in (out or ""):gmatch("[^\r\n]+") do
        local key, value = line:match("([^\t]+)\t(.+)")
        if key == "running" then
          running = value == "1"
        elseif key and value then
          values[key] = value
        end
      end

      last_status = opts.status(values) or last_status

      item:set({
        drawing = running,
        label = { string = last_status, drawing = false },
        icon = { padding_right = DEFAULT_ITEM.icon.padding_right },
      })
    end)
  end

  -- Show progress when hovering, hide when leaving (same as battery.lua).
  item:subscribe("mouse.entered", function()
    item:set({
      icon = { padding_right = DEFAULT_ITEM.icon.padding_right * 0.5 },
      label = { string = last_status, drawing = true },
    })
  end)

  item:subscribe("mouse.exited", function()
    item:set({
      icon = { padding_right = DEFAULT_ITEM.icon.padding_right },
      label = { drawing = false },
    })
  end)

  item:subscribe({ "routine", "system_woke" }, update)

  -- Populate immediately instead of waiting up to update_freq for the first
  -- routine tick.
  update()

  return item
end

return M
