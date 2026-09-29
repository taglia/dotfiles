-- Run from the repository root: lua scripts/check-sketchybar-network.lua
package.path = "files/sketchybar/?.lua;" .. package.path
COLORS = { mocha_overlay_1 = "gray", mocha_text = "white" }
local items, commands = {}, {}
local result = {
  status = "connected",
  ssid = "Home",
  wifi_ip = "192.168.1.20",
  wifi_gateway = "192.168.1.1",
  wired = false,
}
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
local network, ssid = items.network, items["network.ssid"]
local wifi_detail, wired_detail = items["network.detail.wifi"], items["network.detail.wired"]
assert(wifi_detail.config.position == "popup.network" and wired_detail.config.position == "popup.network")
assert(wifi_detail.config.label.string == "Wi-Fi: Home — 192.168.1.20 [192.168.1.1]")
assert(wired_detail.config.label.string == "Wired: Disconnected")
assert(commands[1] == "sketchybar-network-status")
local function update(value)
  result = value
  network.callbacks.routine()
end
assert(ssid.config.label.string == "Home")
assert(network.config.label.string == "󰤨  󰈂")
for _, item in ipairs({ network, ssid }) do
  assert(not item.callbacks["mouse.exited.global"])
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
  assert(wifi_detail.config.label.string == "Wi-Fi: " .. fixture[1] .. " — No IP [Gateway unavailable]")
  assert(wired_detail.config.label.string == "Wired: Speed unavailable — No IP [Gateway unavailable]")
  assert(network.config.label.string == "󰤨  󰈁")
end
update({
  status = "connected",
  ssid = "Office",
  wifi_ip = "192.168.1.20",
  wifi_gateway = "192.168.1.1",
  wired = true,
  wired_links = { { interface = "en7", speed = "2.5 Gbps", ip = "192.168.2.20", gateway = "192.168.2.1" } },
})
assert(wifi_detail.config.label.string == "Wi-Fi: Office — 192.168.1.20 [192.168.1.1]")
assert(wired_detail.config.label.string == "Wired: 2.5 Gbps — 192.168.2.20 [192.168.2.1]")
update({
  status = "disconnected",
  wired = true,
  wired_links = {
    { interface = "en7", speed = "1 Gbps", ip = "192.168.2.20", gateway = "192.168.2.1" },
    { interface = "en8", speed = "10 Gbps", ip = "10.0.0.2", gateway = "10.0.0.1" },
  },
})
assert(wifi_detail.config.label.string == "Wi-Fi: Disconnected")
assert(
  wired_detail.config.label.string
    == "Wired: en7: 1 Gbps — 192.168.2.20 [192.168.2.1]; en8: 10 Gbps — 10.0.0.2 [10.0.0.1]"
)
for _, wired in ipairs({ false, true }) do
  update({ status = "disconnected", wired = wired })
  assert(ssid.config.label.string == "")
  assert(wifi_detail.config.label.string == "Wi-Fi: Disconnected")
  assert(network.config.label.string == "󰤭  " .. (wired and "󰈁" or "󰈂"))
end
update({ status = "connected", ssid = "", reason = "Permission required", wired = true })
assert(ssid.config.label.string == "Unknown")
assert(wifi_detail.config.label.string == "Wi-Fi: Permission required — No IP [Gateway unavailable]")
assert(wired_detail.config.label.string == "Wired: Speed unavailable — No IP [Gateway unavailable]")
assert(network.config.label.string == "󰤨  󰈁")
update("not json")
assert(ssid.config.label.string == "Unknown")
assert(wifi_detail.config.label.string:match("Wi%-Fi status unavailable"))
assert(wired_detail.config.label.string == "Wired: Status unavailable")
result = { status = "connected", ssid = "Recovered", wired = false }
network.callbacks.wifi_change()
assert(ssid.config.label.string == "Recovered")
network.callbacks.system_woke()
network.callbacks["mouse.entered"]()
network.callbacks.routine()
assert(network.config.popup.drawing) -- Refresh does not close an open tooltip.
network.callbacks["mouse.exited"]()
assert(not network.config.popup.drawing)
print("SketchyBar network widget checks passed")
