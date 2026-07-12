#!/usr/bin/env lua

-- SketchyBar config (Lua via SBarLua). Managed by Home Manager; this file is
-- referenced from modules/home/sketchybar.nix via programs.sketchybar.config.source
-- and copied verbatim to ~/.config/sketchybar/sketchybarrc. Because the copy is
-- verbatim, this file carries its own shebang (unlike the inline config.text
-- path, where Home Manager adds one) and must be executable.
--
-- Single-file for now. To grow into a plugin-style multi-file config, switch
-- modules/home/sketchybar.nix to:
--   config = { source = ../../files/sketchybar; recursive = true; };
-- and place Lua modules (colors.lua, items/, ...) next to this sketchybarrc.
-- The Home Manager wrapper adds the config dir to LUA_PATH only in the source
-- path, so require() of siblings then resolves.

sbar = require("sketchybar")

-- (TEMPORARY diagnostic) Truncate the debug log fresh on each config load so
-- stale entries from a previous run don't confuse diagnosis.
do
  local f = io.open("/tmp/sbar_debug.log", "w")
  if f then f:write(os.date("%H:%M:%S config loaded\n")); f:close() end
end
local function dlog(msg)
  local f = io.open("/tmp/sbar_debug.log", "a")
  if f then f:write(os.date("%H:%M:%S ") .. tostring(msg) .. "\n"); f:close() end
end

local white  = 0xffcad3f5
local green  = 0xffa6da95
local bg     = 0xd01e1e2e
local border = 0xff494d64

local font = "SF Pro"
local pad  = 10

sbar.begin_config()

-- Bar geometry / appearance (the --bar domain).
sbar.bar({
  height = 40,
  color = bg,
  border_color = border,
  shadow = true,
  sticky = true,
  padding_right = pad,
  padding_left = pad,
  blur_radius = 20,
  topmost = "window",
})

-- Default item styling (the --default domain).
sbar.default({
  updates = "when_shown",
  icon = {
    font = { family = font, style = "Bold", size = 14.0 },
    color = white,
    padding_left = pad,
    padding_right = pad,
  },
  label = {
    font = { family = font, style = "Semibold", size = 13.0 },
    color = white,
    padding_left = pad,
    padding_right = pad,
  },
  background = { height = 26, corner_radius = 9, border_width = 2 },
})

-- Frontmost app name on the left.
local front_app = sbar.add("item", "front.app", {
  position = "left",
  icon = { drawing = false },
  label = { string = "" },
})
front_app:subscribe("front_app_switched", function(env)
  dlog("front_app_switched: INFO=" .. tostring(env.INFO))
  front_app:set({ label = { string = tostring(env.INFO) } })
end)

-- Clock on the right.
--
-- Uses SketchyBar's NATIVE item `script` scheduler (sketchybar runs the script
-- string on each routine tick, governed by update_freq), NOT SBarLua's
-- sbar.exec / :subscribe path: in the nix-built sbarlua, event/callback
-- delivery does not fire (routine subscribes and sbar.exec completion
-- callbacks never fire), so the clock would stay empty if it relied on them.
-- os.date() (pure Lua, no shell, non-blocking) gives an immediate value at
-- config load; the script keeps it updated every 30s.
local clock = sbar.add("item", "clock", {
  position = "right",
  update_freq = 30,
  updates = "always",
  icon = { drawing = false },
  label = { string = os.date("%a %d %b %H:%M") },
  script = "sketchybar --set clock label=\"$(date '+%a %d %b %H:%M')\"",
})

-- (TEMPORARY diagnostic) Invisible item that subscribes to `routine` via the
-- SBarLua event path, to confirm whether sbarlua event delivery works at all
-- in this build. If /tmp/sbar_debug.log shows "probe routine FIRED", sbarlua
-- events work and only sbar.exec was broken; if it never fires, sbarlua's
-- whole event system is inert here and dynamic widgets must use native scripts.
local probe = sbar.add("item", "probe", {
  position = "right",
  update_freq = 15,
  updates = "always",
  drawing = false,
})
probe:subscribe("routine", function()
  dlog("probe routine FIRED (sbarlua events work)")
end)

sbar.end_config()