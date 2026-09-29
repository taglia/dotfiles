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

-- Only one of these hover popups is open at a time. SketchyBar suppresses
-- mouse.exited on the item -> popup transition when mouse.exited.global is
-- also subscribed; the global event then closes it on leaving the popup.
-- See SketchyBar issue #178, comment 1153011527. No timers or polling needed.
local close_active_hover_popup

function M.hover_popup(parent, triggers, on_change)
  on_change = on_change or function() end
  local is_open = false
  local function close()
    if not is_open then
      return
    end
    is_open = false
    close_active_hover_popup = nil
    parent:set({ popup = { drawing = false } })
    on_change(false)
  end

  local function open()
    if is_open then
      return
    end
    if close_active_hover_popup then
      close_active_hover_popup()
    end
    is_open = true
    close_active_hover_popup = close
    parent:set({ popup = { drawing = true } })
    on_change(true)
  end

  for _, item in ipairs(triggers or { parent }) do
    item:subscribe("mouse.entered", open)
    item:subscribe({ "mouse.exited", "mouse.exited.global" }, close)
  end
  return close, open
end

-- Factory for compact backup-progress indicators (currently CCC).
-- Hidden unless the backup is running; progress appears in a hover popup,
-- never as an expanding label in the bar.
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
    updates = true, -- Keep polling while the indicator is hidden.
    drawing = false,
    icon = {
      string = opts.icon,
      color = opts.icon_color,
      font = { family = "Hack Nerd Font", style = "Regular" },
    },
    label = { drawing = false },
    popup = { align = "right" },
  })
  local detail = SBAR.add("item", opts.name .. ".detail", {
    position = "popup." .. item.name,
    icon = { drawing = false },
    label = {
      string = opts.initial_status,
      font = { family = "Hack Nerd Font", style = "Regular", size = 14.0 },
      padding_left = 14,
      padding_right = 14,
    },
  })
  local close_popup = M.hover_popup(item)

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

      detail:set({ label = { string = last_status } })
      if not running then
        close_popup()
      end
      item:set({ drawing = running })
    end)
  end

  item:subscribe({ "routine", "system_woke" }, update)

  -- Populate immediately instead of waiting up to update_freq for the first
  -- routine tick.
  update()

  return item
end

return M
