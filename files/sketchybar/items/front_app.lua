-- Frontmost-application icon.
-- Shows the icon of the currently focused app, as the leftmost item on the
-- right side of the bar (immediately left of CPU). Hover shows the app name
-- and quit action in a popup without replacing the icon; click quits it.
-- After the app quits,
-- `front_app_switched` fires for the newly focused app and the icon updates.
--
-- The icon is rendered natively by sketchybar via `icon.background.image`.
-- We resolve the frontmost app's *bundle id* and use `app.<bundle-id>` rather
-- than `app.<name>`: sketchybar's `app.<name>` fallback loops running apps and
-- matches the first one whose localized name fits, which is ambiguous for apps
-- like Messages (the faceless `com.apple.messages.AssistantExtension` is also
-- named "Messages" and has no app URL, so sketchybar renders a blank/generic
-- icon -> a "large white block"). Bundle ids are unique and resolve directly.
--
-- Sizing (from sketchybar src/image.c + src/workspace.m): the app icon is
-- rasterized at 32*backing px and image.c divides by backing^2, giving a 32pt
-- base on retina; `image.scale` multiplies it. ICON_SCALE = 1.25 -> 40pt.
-- SLOT matches the icon's drawn size (bar-clipped to 38pt).
-- Tune ICON_SCALE if too big/small.

local utils = require("utils")
local ICON_SCALE = 1.25
local SLOT = 32 * ICON_SCALE -- square side for the icon slot (40pt)
local SLOT_PAD = 4 -- item-level padding so the slot doesn't touch neighbors
local CORNER = 8

-- System / relaunch-only processes we never want to "quit" from the bar.
local NO_QUIT = {
  Finder = true,
  Dock = true,
  SystemUIServer = true,
  ControlCenter = true,
  Spotlight = true,
}

local front_app = SBAR.add("item", "front_app", {
  position = "right",
  padding_left = SLOT_PAD,
  padding_right = SLOT_PAD,
  label = { drawing = false },
  popup = { align = "right" },
  icon = {
    string = "",
    width = SLOT, -- fixed square slot for the app image
    align = "center",
    padding_left = 0,
    padding_right = 0,
    background = {
      drawing = true,
      color = COLORS.transparent, -- transparent when showing the icon
      border_width = 0,
      corner_radius = CORNER,
      height = SLOT,
      image = {
        drawing = true,
        scale = ICON_SCALE,
        padding_left = 0,
        padding_right = 0,
      },
    },
  },
})

local detail = SBAR.add("item", "front_app.detail", {
  position = "popup." .. front_app.name,
  icon = { drawing = false },
  label = {
    string = "No active application",
    font = { family = "Hack Nerd Font", style = "Regular", size = 14.0 },
    padding_left = 14,
    padding_right = 14,
  },
})

local current_app = ""
-- Cache app name -> bundle id (or false if `id of app` failed) so repeated
-- switches to the same app don't re-shell-out.
local bid_cache = {}

local function set_icon_image(source)
  front_app:set({
    icon = {
      string = "",
      background = {
        color = COLORS.transparent,
        border_width = 0,
        image = { drawing = true, string = source },
      },
    },
  })
end

local function update_detail()
  local text = "No active application"
  if current_app ~= "" then
    text = current_app .. (NO_QUIT[current_app] and " — Quit disabled" or " — Click to quit")
  end
  detail:set({ label = { string = text } })
end

-- Escape an app name for embedding as an AppleScript "..." literal inside a
-- single-quoted `osascript -e '...'` shell argument: backslash-escape for the
-- AppleScript string first, then close/reopen the shell single quotes ('\'')
-- around any ' in the name so it can't break out of the shell quoting.
local function quote_for_osascript(name)
  local applescript = name:gsub("\\", "\\\\"):gsub('"', '\\"')
  return (applescript:gsub("'", "'\\''"))
end

-- Resolve the app name to a bundle id (unique, avoids sketchybar's ambiguous
-- name loop) and show its icon. Falls back to `app.<name>` if resolution fails.
local function show_icon(app_name)
  current_app = app_name or ""
  update_detail()
  local cached = bid_cache[app_name]
  if cached ~= nil then
    set_icon_image(cached and ("app." .. cached) or ("app." .. app_name))
    return
  end
  local safe = quote_for_osascript(app_name)
  SBAR.exec(string.format([[osascript -e 'id of app "%s"' 2>/dev/null]], safe), function(out)
    local bid = (out or ""):match("[^\r\n]+")
    if bid and bid ~= "" then
      bid_cache[app_name] = bid
      set_icon_image("app." .. bid)
    else
      bid_cache[app_name] = false
      set_icon_image("app." .. app_name)
    end
  end)
end

front_app:subscribe("front_app_switched", function(env)
  local app_name = env.INFO or ""
  if app_name ~= "" then
    show_icon(app_name)
  end
end)

local close_popup = utils.hover_popup(front_app, nil, function(open)
  if open then
    update_detail()
  end
end)

front_app:subscribe("mouse.clicked", function()
  local app = current_app
  if app == "" or NO_QUIT[app] then
    return
  end
  close_popup()
  -- Quit by localized name (matches what front_app_switched reports). Swallow
  -- errors (unknown app -> no-op).
  local safe = quote_for_osascript(app)
  SBAR.exec(string.format([[osascript -e 'tell application "%s" to quit' 2>/dev/null; true]], safe))
end)

-- Best-effort initial population so the icon shows on (re)load.
SBAR.exec(
  [[osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true']],
  function(out)
    local name = (out or ""):match("[^\r\n]+")
    if name and name ~= "" then
      show_icon(name)
    end
  end
)
