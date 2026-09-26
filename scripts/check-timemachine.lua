-- Run from the repository root: lua scripts/check-timemachine.lua
package.path = "files/sketchybar/?.lua;" .. package.path
COLORS = { mocha_green = "green", mocha_overlay_1 = "gray", mocha_peach = "warning" }
DEFAULT_ITEM = { icon = { padding_right = 8 }, label = { color = "normal" } }
local items = {}
local probe = "running\t0\nphase\tIdle"
local history = "history\tok"
local history_code = 0
local function backups(age)
  local epoch = os.time() - age
  local out = "history\tok\ndestination\tDisk\nlast_backup\t" .. epoch
  for i = 1, 5 do
    out = out .. "\nbackup_" .. i .. "\t" .. (epoch - (i - 1) * 86400)
  end
  return out
end
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
    local is_history = command:match("history.sh")
    callback(is_history and history or probe, is_history and history_code or 0)
  end,
}
dofile("files/sketchybar/items/timemachine.lua")
local tm = items.timemachine
local function fire(event)
  tm.callbacks[event]()
end
local function has(text)
  for i = 1, 13 do
    local row = items["timemachine.detail." .. i].config
    if row.drawing and row.label.string:find(text, 1, true) then
      return row
    end
  end
end
assert(tm.config.drawing == false and tm.config.updates == true)
probe = "running\t1\nphase\tCopying\npercent\t42\nremaining\t120\nbytes\t42000000000\ntotal_bytes\t100000000000"
fire("routine")
assert(tm.config.drawing)
fire("mouse.entered")
assert(tm.config.label.string == "Copying 42%" and tm.config.label.drawing)
assert(tm.config.icon.color == "green")
history = backups(8 * 86400)
fire("mouse.clicked")
assert(tm.config.popup.drawing)
for i = 0, 4 do
  assert(has("• " .. os.date("%Y-%m-%d", os.time() - (8 + i) * 86400)))
end
assert(not has("Destination:"))
assert(has("Data: 42.0 GB / 100.0 GB"))
assert(has("Last successful: 8 d"))
assert(has("Warning:").label.color == "warning")
assert(has("Estimated remaining: 2 min"))
for _, fixture in ipairs({
  { "0", "999", "0 B / 999 B" },
  { "1500", "2000000", "1.5 KB / 2.0 MB" },
  { "2500000000000", "5000000000000", "2.5 TB / 5.0 TB" },
}) do
  probe = "running\t1\nphase\tCopying\nbytes\t" .. fixture[1] .. "\ntotal_bytes\t" .. fixture[2]
  fire("routine")
  assert(has("Data: " .. fixture[3]))
end
probe = "running\t1\nphase\tVerifying"
fire("routine")
assert(tm.config.label.string == "Verifying")
assert(not has("Estimated remaining:") and not has("Data:"))
history = backups(60)
fire("routine")
assert(not has("Warning:"))
assert(has("Last successful: 1 min"))
history = "history\tunavailable"
history_code = 1
fire("routine")
assert(has("Last successful: 1 min")) -- Transient failure retains the known date.
assert(has("History refresh failed"))
history_code = 0
history = "history\tok"
fire("routine")
assert(has("Last successful: History unavailable"))
assert(not has("Warning:") and not has("Latest available backups:"))
fire("mouse.exited")
assert(not tm.config.label.drawing)
fire("mouse.clicked")
assert(not tm.config.popup.drawing)
probe = "running\t0\nphase\tIdle"
fire("routine")
assert(not tm.config.drawing) -- Missing history alone is not an overdue backup.
history = backups(60)
fire("routine")
assert(not tm.config.drawing)
history = backups(8 * 86400)
fire("routine")
assert(tm.config.drawing and tm.config.icon.color == "warning")
fire("mouse.entered")
assert(tm.config.label.string == "Backup over a week old")
fire("mouse.clicked")
assert(tm.config.popup.drawing and has("Warning:"))
history = backups(0)
fire("routine")
assert(not tm.config.drawing and not tm.config.popup.drawing)
print("PASS Time Machine visibility, hover, popup, ETA, history, and warning")
