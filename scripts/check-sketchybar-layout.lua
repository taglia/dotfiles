-- Run from the repository root: lua scripts/check-sketchybar-layout.lua
-- Execute init.lua with the moved modules intact. Unchanged outer widgets are
-- stand-ins; all shell probes and application launches are mocked.
package.path = "files/sketchybar/?.lua;" .. package.path
package.loaded.globals = true
COLORS = { mocha_red = "red", mocha_green = "green", mocha_text = "white" }
DEFAULT_ITEM = {
  icon = { padding_left = 8, padding_right = 8, font = { size = 18 } },
  label = { padding_right = 8 },
}
local items, brackets, left, right, commands = {}, {}, {}, {}, {}
local now, counters = 100, "1000 2000"
local begin_count, end_count = 0, 0
SBAR = {
  begin_config = function()
    begin_count = begin_count + 1
  end,
  end_config = function()
    end_count = end_count + 1
  end,
  add = function(kind, name, config, bracket_config)
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
    assert(not items[name], "Duplicate item: " .. name)
    items[name] = item
    if kind == "bracket" then
      brackets[name] = config
    elseif config.position == "left" then
      table.insert(left, name)
    elseif config.position == "right" then
      table.insert(right, 1, name) -- Right-side creation order is reversed on screen.
    end
    return item
  end,
  exec = function(command, callback)
    commands[#commands + 1] = command
    if callback and command:find("netstat", 1, true) then
      callback(counters)
    end
  end,
}
local function stand_in(module, name, position)
  package.preload["items." .. module] = function()
    SBAR.add("item", name, { position = position })
  end
end
stand_in("spaces", "spaces", "left")
for _, name in ipairs({ "calendar", "volume", "battery", "front_app", "timemachine", "ccc" }) do
  stand_in(name, name, "right")
end
local original_popen, original_time = io.popen, os.time
io.popen = function()
  return {
    read = function()
      return "8"
    end,
    close = function() end,
  }
end
os.time = function()
  return now
end

dofile("files/sketchybar/init.lua")
assert(begin_count == 1 and end_count == 1)
assert(
  table.concat(left, ",") == "spaces,network,network.ssid,bandwidth.up,bandwidth.down,vpn",
  table.concat(left, ",")
)
assert(
  table.concat(right, ",") == "ccc,timemachine,front_app,cpu,memory,disk,battery,volume,calendar",
  table.concat(right, ",")
)
assert(items.network.config.width == 0 and items["bandwidth.up"].config.width == 0)
assert(items.cpu.config.popup.align == "right" and items.memory.config.popup.align == "right")
assert(items.vpn.config.popup.align == "left")
assert(table.concat(brackets["resources.bracket"], ",") == "cpu,memory,disk")
assert(table.concat(brackets["bandwidth.bracket"], ",") == "bandwidth.up,bandwidth.down")
for _, members in pairs(brackets) do
  local position = items[members[1]].config.position
  for _, name in ipairs(members) do
    assert(items[name].config.position == position, "Bracket crosses bar sides")
  end
end

-- The extracted bandwidth widget still initializes immediately, ticks once for
-- both rows, handles counter resets, and opens Little Snitch from either row.
local up, down = items["bandwidth.up"], items["bandwidth.down"]
assert(up.config.label.string:match("0 B/s$") and down.config.label.string:match("0 B/s$"))
assert(not up.callbacks.routine and down.config.update_freq == 2)
now, counters = 102, "5096 4048"
local before = #commands
down.callbacks.routine()
assert(#commands == before + 1)
assert(up.config.label.string:match("1.0 KB/s$") and down.config.label.string:match("2.0 KB/s$"))
now, counters = 104, "0 0"
down.callbacks.routine()
assert(up.config.label.string:match("0 B/s$") and down.config.label.string:match("0 B/s$"))
for _, item in ipairs({ up, down }) do
  item.callbacks["mouse.clicked"]()
  assert(commands[#commands] == 'open -a "Little Snitch Network Monitor"')
end
io.popen, os.time = original_popen, original_time
print("SketchyBar layout and bandwidth checks passed")
