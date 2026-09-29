-- Run from the repository root: lua scripts/check-sketchybar-network.lua
COLORS = { mocha_overlay_1 = "gray", mocha_text = "white" }
local items, commands = {}, {}
local result = { status = "connected", ssid = "Home", wired = false }
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
    table.insert(commands, command)
    if callback then
      callback(result)
    end
  end,
}
dofile("files/sketchybar/items/network.lua")
local network, ssid, detail = items.network, items["network.ssid"], items["network.detail"]
assert(commands[1] == "sketchybar-network-status")
local function update(value)
  result = value
  network.callbacks.routine()
end
assert(ssid.config.label.string == "Home")
assert(network.config.label.string == "󰤨  󰈂")
for _, item in ipairs({ network, ssid }) do
  item.callbacks["mouse.entered"]()
  assert(network.config.popup.drawing)
  item.callbacks["mouse.exited"]()
  assert(not network.config.popup.drawing)
  item.callbacks["mouse.clicked"]()
  assert(commands[#commands] == "open 'x-apple.systempreferences:com.apple.preference.network'")
end
for _, fixture in ipairs({
  { "1234567890", "1234567890" },
  { "12345678901", "1234567890…" },
  { "ééééééééééé", "éééééééééé…" },
  { "Wi-Fi ' $(test)", "Wi-Fi ' $(…" },
}) do
  update({ status = "connected", ssid = fixture[1], wired = true })
  assert(ssid.config.label.string == fixture[2], ssid.config.label.string)
  assert(detail.config.label.string == fixture[1] .. "  |  Wired: connected")
  assert(network.config.label.string == "󰤨  󰈁")
end
for _, wired in ipairs({ false, true }) do
  update({ status = "disconnected", wired = wired })
  assert(ssid.config.label.string == "")
  assert(network.config.label.string == "󰤭  " .. (wired and "󰈁" or "󰈂"))
end
update({ status = "connected", ssid = "", reason = "Permission required", wired = true })
assert(ssid.config.label.string == "Unknown")
assert(detail.config.label.string == "Permission required  |  Wired: connected")
assert(network.config.label.string == "󰤨  󰈁")
update("not json")
assert(ssid.config.label.string == "Unknown")
assert(detail.config.label.string:match("Wi%-Fi status unavailable"))
result = { status = "connected", ssid = "Recovered", wired = false }
network.callbacks.wifi_change()
assert(ssid.config.label.string == "Recovered")
network.callbacks.system_woke()
network.callbacks["mouse.entered"]()
network.callbacks.routine()
assert(network.config.popup.drawing) -- Refresh does not close an open tooltip.
network.callbacks["mouse.exited.global"]()
assert(not network.config.popup.drawing)
print("SketchyBar network widget checks passed")
