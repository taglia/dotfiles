-- Run from the repository root: lua scripts/check-sketchybar-network.lua
package.path = "files/sketchybar/?.lua;" .. package.path
COLORS = { mocha_overlay_1 = "gray", mocha_text = "white" }
local items, commands, popup_rows = {}, {}, {}
local public_out, public_code = "203.0.113.7\n", 0
local public_requests, public_callback, defer_public = 0, nil, false
local clock, original_time = 1000, os.time
os.time = function()
  return clock
end
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
    if config.position == "popup.network" then
      popup_rows[#popup_rows + 1] = name
    end
    return item
  end,
  exec = function(command, callback)
    table.insert(commands, command)
    if command:find("https://api.ipify.org", 1, true) then
      assert(command:find("--max-time 5", 1, true) and command:find("--connect-timeout 3", 1, true))
      assert(command:find("--max-filesize 64", 1, true) and command:find("--ipv4", 1, true))
      assert(command:find("/usr/bin/curl -q", 1, true) and command:find("--fail", 1, true))
      public_requests = public_requests + 1
      if defer_public then
        assert(not public_callback, "Overlapping public-IP requests")
        public_callback = callback
      else
        callback(public_out, public_code)
      end
    elseif callback then
      callback(result)
    end
  end,
}
dofile("files/sketchybar/items/network.lua")
local network, ssid = items.network, items["network.ssid"]
local wifi_detail, wired_detail = items["network.detail.wifi"], items["network.detail.wired"]
local public_detail = items["network.detail.public"]
assert(table.concat(popup_rows, ",") == "network.detail.wifi,network.detail.wired,network.detail.public")
assert(public_requests == 0) -- No external request at startup or while hidden.
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
-- Public IP: successful lookups are cached across hover/reopen and local ticks.
assert(public_detail.config.label.string == "Public IP: 203.0.113.7")
local count = public_requests
clock = clock + 59
network.callbacks["mouse.entered"]()
network.callbacks.routine()
assert(public_requests == count)
clock = clock + 1
public_out = "198.51.100.8"
network.callbacks.routine()
assert(public_requests == count + 1)
assert(public_detail.config.label.string == "Public IP: 198.51.100.8")

-- Never render arbitrary service output or a successful-looking IP after a
-- curl failure. Failed requests use the same cooldown, not a hover retry loop.
for _, fixture in ipairs({
  { "not an IP", 0 },
  { "256.1.2.3", 0 },
  { "203.0.113.7\nextra content", 0 },
  { { ip = "203.0.113.7" }, 0 },
  { string.rep(" ", 65), 0 },
  { "203.0.113.7", 28 },
  { "", 22 },
}) do
  clock = clock + 60
  public_out, public_code = fixture[1], fixture[2]
  network.callbacks.routine()
  assert(public_detail.config.label.string == "Public IP: Unavailable")
  count = public_requests
  network.callbacks["mouse.exited"]()
  network.callbacks["mouse.entered"]()
  assert(public_requests == count)
end

-- Slow lookups cannot block local details or overlap. Network changes discard
-- an in-flight response from the old connection and retry once it finishes.
clock = clock + 60
defer_public = true
network.callbacks.routine()
assert(public_callback and public_detail.config.label.string == "Public IP: Checking…")
count = public_requests
result = { status = "connected", ssid = "Local updated", wired = false }
clock = clock + 60
network.callbacks.routine()
assert(public_requests == count and ssid.config.label.string == "Local upda…")
network.callbacks.wifi_change()
assert(public_requests == count)
local callback = public_callback
public_callback = nil
callback("198.51.100.99", 0)
assert(public_requests == count + 1 and public_callback)
assert(public_detail.config.label.string == "Public IP: Checking…")
network.callbacks["mouse.exited"]()
callback = public_callback
public_callback = nil
callback("203.0.113.99", 0)
assert(public_detail.config.label.string == "Public IP: 203.0.113.99")
assert(not network.config.popup.drawing) -- Completing a lookup never reopens it.
clock = clock + 60
count = public_requests
network.callbacks.routine()
network.callbacks.system_woke()
assert(public_requests == count) -- Hidden popups make no external requests.
network.callbacks["mouse.entered"]()
assert(public_requests == count + 1 and public_callback)
callback = public_callback
public_callback = nil
callback("203.0.113.10", 0)
assert(public_detail.config.label.string == "Public IP: 203.0.113.10")
os.time = original_time
print("SketchyBar network widget checks passed")
