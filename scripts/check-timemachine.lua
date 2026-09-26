-- Run from the repository root: lua scripts/check-timemachine.lua
package.path = "files/sketchybar/?.lua;" .. package.path
COLORS = { mocha_green = "green", mocha_overlay_1 = "gray", mocha_peach = "warning" }
DEFAULT_ITEM = { icon = { padding_right = 8 }, label = { color = "normal" } }
local items = {}
local probe = "running\t0\nphase\tIdle"
local history = ""
SBAR = {
  add = function(_, name, config)
    local item = { name = name, config = config, callbacks = {} }
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
    callback(command:match("history.js") and history or probe)
  end,
}
dofile("files/sketchybar/items/timemachine.lua")
local tm = items.timemachine
local function fire(event)
  tm.callbacks[event]()
end
local function has(text)
  for i = 1, 6 do
    local row = items["timemachine.detail." .. i].config
    if row.drawing and row.label.string:find(text, 1, true) then
      return row
    end
  end
end
assert(tm.config.drawing == false and tm.config.updates == true)
probe = "running\t1\nphase\tCopying\npercent\t42\nremaining\t120"
fire("routine")
assert(tm.config.drawing)
fire("mouse.entered")
assert(tm.config.label.string == "Copying 42%" and tm.config.label.drawing)
assert(tm.config.icon.color == "green")
history = "destination\tDisk\nlast_backup\t" .. (os.time() - 8 * 86400)
fire("mouse.clicked")
assert(tm.config.popup.drawing)
assert(has("Last successful: " .. os.date("%Y-%m-%d", os.time() - 8 * 86400)))
assert(has("Age: 8 d"))
assert(has("Warning:").label.color == "warning")
assert(has("Estimated remaining: 2 min"))
probe = "running\t1\nphase\tVerifying"
fire("routine")
assert(tm.config.label.string == "Verifying")
assert(not has("Estimated remaining:"))
history = "destination\tDisk\nlast_backup\t" .. (os.time() - 60)
fire("routine")
assert(not has("Warning:"))
assert(has("Age: 1 min"))
history = "history\tunavailable"
fire("routine")
assert(has("Last successful: History unavailable"))
assert(not has("Warning:") and not has("Age:"))
fire("mouse.exited")
assert(not tm.config.label.drawing)
fire("mouse.clicked")
assert(not tm.config.popup.drawing)
probe = "running\t0\nphase\tIdle"
fire("routine")
assert(not tm.config.drawing) -- Missing history alone is not an overdue backup.
history = "last_backup\t" .. (os.time() - 60)
fire("routine")
assert(not tm.config.drawing)
history = "last_backup\t" .. (os.time() - 8 * 86400)
fire("routine")
assert(tm.config.drawing and tm.config.icon.color == "warning")
fire("mouse.entered")
assert(tm.config.label.string == "Backup over a week old")
fire("mouse.clicked")
assert(tm.config.popup.drawing and has("Warning:"))
history = "last_backup\t" .. os.time()
fire("routine")
assert(not tm.config.drawing and not tm.config.popup.drawing)
print("PASS Time Machine visibility, hover, popup, ETA, history, and warning")
