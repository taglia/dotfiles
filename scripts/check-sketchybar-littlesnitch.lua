-- Pure display tests: no daemon, sudo, GUI events, or Little Snitch required.
local result, code = nil, 1
local items, commands = {}, {}
local now = os.time()
COLORS = { mocha_red = "red", mocha_yellow = "yellow", mocha_peach = "theme-amber" }
package.loaded.utils = {
  hover_popup = function(parent)
    return function()
      parent:set({ popup = { drawing = false } })
    end
  end,
}
SBAR = {
  add = function(_, name, config)
    local item = { name = name, config = config, callbacks = {} }
    function item:set(values)
      for key, value in pairs(values) do
        if type(value) == "table" then
          self.config[key] = self.config[key] or {}
          for k, v in pairs(value) do
            self.config[key][k] = v
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
    commands[#commands + 1] = command
    if callback then
      callback(result, code)
    end
  end,
}
dofile("files/sketchybar/items/littlesnitch.lua")
local item = items.littlesnitch
assert(item.config.position == "left" and item.config.updates == true)
assert(item.config.icon.string == "􀞟" and item.config.icon.font.size == 26)
assert(item.config.drawing and item.config.icon.color == COLORS.mocha_peach)
local function update(value, exit)
  result, code = value, exit or 0
  item.callbacks.routine()
end
local function status(mode, enabled)
  return { version = 1, checked_at = now, mode = mode, filter_enabled = enabled }
end
for mode = 0, 2 do
  for _, enabled in ipairs({ true, false }) do
    update(status(mode, enabled))
    local warning = mode == 1 or not enabled
    assert(item.config.drawing == warning)
    if warning then
      assert(item.config.icon.color == "red")
    end
  end
end
for _, bad in ipairs({ "garbage", {}, { version = 2, checked_at = now } }) do
  update(bad)
  assert(item.config.drawing and item.config.icon.color == COLORS.mocha_peach)
end
for _, timestamp in ipairs({ now - 120, now + 120 }) do
  local value = status(0, true)
  value.checked_at = timestamp
  update(value)
  assert(item.config.drawing and item.config.icon.color == COLORS.mocha_peach)
end
update(status(0, true), 1)
assert(item.config.drawing and item.config.icon.color == COLORS.mocha_peach)
update(status(nil, false))
assert(item.config.drawing and item.config.icon.color == "red")
update(status(1, nil))
assert(item.config.drawing and item.config.icon.color == "red")
update(status(nil, true))
assert(item.config.drawing and item.config.icon.color == COLORS.mocha_peach)
local disabled = status(nil, nil)
disabled.error_kind = "cli_disabled"
update(disabled)
assert(item.config.drawing and item.config.icon.color == COLORS.mocha_peach)
assert(items["littlesnitch.detail"].config.label.string == "Little Snitch: CLI not enabled")
assert(items["littlesnitch.help"].config.drawing)
update(status(1, false))
local text = items["littlesnitch.detail"].config.label.string
assert(text:find("network filter disabled", 1, true) and text:find("Silent Allow enabled", 1, true))
assert(not items["littlesnitch.help"].config.drawing)
update(status(0, true))
assert(not item.config.drawing and not item.config.popup.drawing)
local failed = status(nil, nil)
failed.failures = {
  activeSilentMode = { kind = "exit", code = 14 },
  networkFilterEnabled = { kind = "timeout", seconds = 10 },
}
update(failed)
local mode_row = items["littlesnitch.diagnostic.activeSilentMode"]
local filter_row = items["littlesnitch.diagnostic.networkFilterEnabled"]
assert(mode_row.config.drawing and mode_row.config.label.string == "activeSilentMode: CLI exit code 14")
assert(
  filter_row.config.drawing and filter_row.config.label.string == "networkFilterEnabled: timed out after 10 seconds"
)
failed.failures.activeSilentMode = { kind = "parse_failure" }
failed.failures.networkFilterEnabled = { kind = "os_error", errno = 13 }
update(failed)
assert(mode_row.config.label.string:find("parsing failure", 1, true))
assert(filter_row.config.label.string:find("errno 13", 1, true))
failed.checked_at = now - 120
update(failed)
assert(not mode_row.config.drawing and not filter_row.config.drawing)
update(status(0, true))
assert(not mode_row.config.drawing and not filter_row.config.drawing)
item.callbacks["mouse.clicked"]()
assert(commands[#commands] == '/usr/bin/open -a "Little Snitch"')
local file = assert(io.open("files/sketchybar/init.lua"))
local init = file:read("*a")
file:close()
assert(init:find('require("items.vpn")\nrequire("items.littlesnitch")', 1, true))
print("Little Snitch widget checks passed")
