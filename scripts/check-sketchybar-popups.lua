-- Run from the repository root: lua scripts/check-sketchybar-popups.lua
package.path = "files/sketchybar/?.lua;" .. package.path
COLORS = {
  mocha_red = "red",
  mocha_peach = "peach",
  mocha_green = "green",
  mocha_mantle = "mantle",
  mocha_overlay_1 = "gray",
  mocha_overlay_0 = "gray",
  mocha_sapphire = "blue",
}
DEFAULT_ITEM = {
  icon = { color = "white", padding_left = 8, padding_right = 8, font = { size = 18 } },
  label = { color = "white", padding_right = 8, font = { size = 18 } },
}
local items, commands = {}, {}
local deferred, defer = {}, false
local ccc_status = "running\t1\npercent\t42"
SBAR = {
  add = function(_, name, config, bracket_config)
    local item = { name = name, config = bracket_config or config, callbacks = {} }
    function item:set(values)
      for key, value in pairs(values) do
        if type(value) == "table" then
          self.config[key] = self.config[key] or {}
          for field, v in pairs(value) do
            self.config[key][field] = v
          end
        else
          self.config[key] = value
        end
      end
    end
    function item:subscribe(events, callback)
      for _, event in ipairs(type(events) == "table" and events or { events }) do
        self.callbacks[event] = callback
      end
    end
    items[name] = item
    return item
  end,
  exec = function(command, callback)
    table.insert(commands, command)
    if not callback then
      return
    end
    local out = "20"
    if command:find("ps ax", 1, true) then
      out = "35.0\t/Applications/Test.app/Contents/MacOS/Test"
    elseif command:find("netstat", 1, true) then
      out = "1000 2000"
    elseif command:find("ccc-status.sh", 1, true) then
      out = ccc_status
    elseif command:find("id of app", 1, true) then
      out = "com.example.Test"
    elseif command:find("frontmost is true", 1, true) then
      out = "Example"
    elseif command:find("vpn-status.sh", 1, true) then
      out = "status\tconnected\nname\tTailscale\ntailscale\tConnected"
    elseif command:find("next-dst-change.sh", 1, true) then
      out = "Next DST change: test"
    elseif command:find("TZ=", 1, true) then
      out = "Paris\t202609291200\t12:00 PM\t20260929"
    end
    if defer then
      table.insert(deferred, function()
        callback(out)
      end)
    else
      callback(out)
    end
  end,
}
-- Do not run real sysctl (or any app/process probes) in this test.
local popen = io.popen
io.popen = function()
  return {
    read = function()
      return "8"
    end,
    close = function() end,
  }
end
dofile("files/sketchybar/items/resources.lua")
io.popen = popen
dofile("files/sketchybar/items/calendar.lua")
dofile("files/sketchybar/items/vpn.lua")
dofile("files/sketchybar/items/ccc.lua")
dofile("files/sketchybar/items/front_app.lua")

local function fire(name, event, env)
  assert(items[name].callbacks[event], name .. ": missing " .. event)(env)
end
local function visible(name)
  return items[name].config.popup.drawing == true
end
local function ticking()
  return items["resources.popup_ticker"].config.updates == true
end
for _, name in ipairs({ "cpu", "memory", "cal.time", "cal.date", "vpn", "ccc", "front_app" }) do
  for _, event in ipairs({ "mouse.entered", "mouse.exited", "mouse.exited.global" }) do
    assert(items[name].callbacks[event])
  end
end
fire("cpu", "mouse.entered")
assert(visible("cpu") and ticking())
assert(items["cpu.top.1"].config.drawing)
local count = #commands
fire("cpu", "mouse.entered")
assert(#commands == count) -- No duplicate probe on repeated enter.
fire("cpu", "mouse.exited")
assert(not visible("cpu") and not ticking())
fire("cpu", "mouse.entered")
-- SketchyBar suppresses item exit on crossing into its popup when global exit
-- is subscribed. The popup stays visible until it delivers a global exit.
assert(visible("cpu"))
fire("cpu", "mouse.exited.global")
assert(not visible("cpu") and not ticking())
fire("cpu", "mouse.entered")
fire("memory", "mouse.entered")
assert(not visible("cpu") and visible("memory") and ticking())
fire("cpu", "mouse.exited") -- A stale exit must not close the new popup.
assert(visible("memory") and ticking())
fire("memory", "mouse.clicked")
assert(commands[#commands] == "open -b com.apple.ActivityMonitor")
assert(not visible("memory") and not ticking())
fire("cpu", "mouse.entered")
fire("cpu", "mouse.clicked")
assert(commands[#commands] == "open -b com.apple.ActivityMonitor")
assert(not visible("cpu") and not ticking())
fire("disk", "mouse.clicked")
assert(commands[#commands] == "open -b com.apple.DiskUtility")

fire("memory", "mouse.entered")
fire("cal.time", "mouse.entered")
assert(visible("cal.time") and not visible("memory") and not ticking())
assert(items["cal.zone.1"].config.drawing)
assert(items["cal.dst"].config.label.string == "Next DST change: test")
fire("cal.time", "routine")
assert(visible("cal.time"))
fire("cal.time", "mouse.exited.global")
assert(not visible("cal.time"))
fire("cal.date", "mouse.entered")
assert(visible("cal.time"))
fire("cal.date", "mouse.exited")
assert(not visible("cal.time"))
for _, name in ipairs({ "cal.time", "cal.date" }) do
  fire(name, "mouse.entered")
  assert(visible("cal.time"))
  fire(name, "mouse.clicked")
  assert(commands[#commands] == "open -b com.fabriceleyne.theclock")
  assert(not visible("cal.time"))
end

fire("vpn", "mouse.entered")
assert(visible("vpn"))
assert(items["vpn.detail.1"].config.label.string == "VPN: Tailscale")
fire("vpn", "mouse.clicked")
assert(commands[#commands] == 'open -a "Tailscale"')
assert(not visible("vpn"))
fire("vpn", "mouse.entered")
fire("vpn", "mouse.exited.global")
assert(not visible("vpn"))

-- CCC progress stays in a popup, including during refreshes, and hiding an
-- idle indicator resets its hover controller before the next backup starts.
assert(items.ccc.config.updates and items.ccc.config.drawing)
assert(not items.ccc.config.label.drawing)
local ccc_padding = items.ccc.config.icon.padding_right
fire("ccc", "mouse.entered")
assert(visible("ccc") and items["ccc.detail"].config.label.string == "42%")
ccc_status = "running\t1\npercent\t75"
fire("ccc", "routine")
assert(visible("ccc") and items["ccc.detail"].config.label.string == "75%")
assert(not items.ccc.config.label.drawing and items.ccc.config.icon.padding_right == ccc_padding)
ccc_status = "running\t0"
fire("ccc", "routine")
assert(not visible("ccc") and not items.ccc.config.drawing)
ccc_status = "running\t1\nphase\tPreparing"
fire("ccc", "routine")
fire("ccc", "mouse.entered")
assert(visible("ccc") and items["ccc.detail"].config.label.string == "Preparing")

-- Front-app hover describes the action without replacing the app icon.
fire("front_app", "mouse.entered")
assert(visible("front_app") and not visible("ccc"))
assert(items["front_app.detail"].config.label.string == "Example — Click to quit")
assert(items.front_app.config.icon.string == "" and items.front_app.config.icon.background.image.drawing)
assert(not items.front_app.config.label.drawing)
fire("front_app", "mouse.clicked")
assert(commands[#commands]:find('tell application "Example" to quit', 1, true))
assert(not visible("front_app"))
fire("front_app", "front_app_switched", { INFO = "Finder" })
fire("front_app", "mouse.entered")
assert(items["front_app.detail"].config.label.string == "Finder — Quit disabled")
local before_quit = #commands
fire("front_app", "mouse.clicked")
assert(#commands == before_quit)
fire("front_app", "mouse.exited.global")
assert(not visible("front_app"))

-- Late async process results must not reopen a dismissed popup or its ticker.
defer = true
fire("cpu", "mouse.entered")
fire("cpu", "mouse.exited")
for _, callback in ipairs(deferred) do
  callback()
end
assert(not visible("cpu") and not ticking())
print("SketchyBar hover popup and click-action checks passed")
