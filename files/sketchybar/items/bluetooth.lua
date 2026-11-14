-- Actual Bluetooth connections come from macOS, not AirBuddy's `connected`
-- flag (which also includes nearby iPhones/iPads/Watches). Each popup row is
-- two columns: device name left, battery right-aligned. Battery comes from
-- AirBuddy when its scripting is enabled, else from macOS: system_profiler
-- carries levels for audio devices, the IO registry (helpers/
-- bluetooth-batteries.sh) for Magic Keyboard/Trackpad/Mouse-class HID devices.
-- AirBuddy also provides the native menu on click.
local utils = require("utils")
local helpers = utils.config_dir() .. "/helpers/"
local function quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local bluetooth = SBAR.add("item", "bluetooth", {
  position = "right",
  icon = { string = "" },
  label = { drawing = false },
  popup = { align = "right" },
})

local ROW_WIDTH = 380
local BATTERY_WIDTH = 140
local ROW_FONT = { family = "Hack Nerd Font", style = "Regular", size = 14.0 }

local rows = {}
local popup_open = false
local busy = false
-- values: list of { name = string, battery = string|nil }. A row without a
-- battery (status messages, devices with no reading) spans the full width.
local function set_rows(values)
  for i, value in ipairs(values) do
    if not rows[i] then
      rows[i] = SBAR.add("item", "bluetooth.device." .. i, {
        position = "popup." .. bluetooth.name,
        icon = {
          font = ROW_FONT,
          align = "left",
          width = ROW_WIDTH,
          padding_left = 16,
          padding_right = 0,
        },
        label = {
          font = ROW_FONT,
          align = "right",
          width = BATTERY_WIDTH,
          padding_left = 0,
          padding_right = 16,
        },
      })
    end
    local battery = value.battery
    if battery == "" then
      battery = nil
    end
    rows[i]:set({
      icon = { string = value.name, width = battery and (ROW_WIDTH - BATTERY_WIDTH) or ROW_WIDTH },
      label = { string = battery or "", drawing = battery ~= nil },
      drawing = true,
    })
  end
  for i = #values + 1, #rows do
    rows[i]:set({ drawing = false })
  end
end

local function address(s)
  return (s or ""):lower():gsub("[^%da-f]", "")
end

local function system_battery(device)
  local parts = {}
  for _, field in ipairs({
    { "device_batteryLevelMain", "" },
    { "device_batteryLevelLeft", "L " },
    { "device_batteryLevelRight", "R " },
    { "device_batteryLevelCase", "Case " },
  }) do
    if device[field[1]] then
      parts[#parts + 1] = field[2] .. device[field[1]]
    end
  end
  return table.concat(parts, " · ")
end

local function refresh()
  if not popup_open or busy then
    return
  end
  busy = true
  -- SketchyBar decodes JSON output into a Lua table. Run asynchronously and
  -- bound system_profiler's collection time; never overlap probes.
  SBAR.exec("/usr/sbin/system_profiler SPBluetoothDataType -json -timeout 5", function(data, code)
    if code ~= 0 or type(data) ~= "table" or type(data.SPBluetoothDataType) ~= "table" then
      busy = false
      set_rows({ { name = "Bluetooth status unavailable" } })
      return
    end
    local devices = {}
    local powered = false
    for _, controller in ipairs(data.SPBluetoothDataType) do
      local properties = controller.controller_properties or {}
      powered = powered or properties.controller_state == "attrib_on"
      for _, entry in ipairs(controller.device_connected or {}) do
        for name, info in pairs(entry) do
          devices[#devices + 1] = { name = name, info = info }
        end
      end
    end
    table.sort(devices, function(a, b)
      return a.name:lower() < b.name:lower()
    end)
    -- Both helpers print "address<TAB>battery" lines; earlier sources win.
    local batteries = {}
    local function merge(out, status)
      if status == 0 and type(out) == "string" then
        for addr, text in out:gmatch("([^\t\r\n]+)\t([^\r\n]+)") do
          local key = address(addr)
          if batteries[key] == nil then
            batteries[key] = text
          end
        end
      end
    end
    local function finish()
      local values = {}
      for _, device in ipairs(devices) do
        local battery = batteries[address(device.info.device_address)]
        if battery == nil or battery == "" then
          battery = system_battery(device.info)
        end
        values[#values + 1] = { name = device.name:gsub("[%c]", " "), battery = battery }
      end
      if #values == 0 then
        values[1] = { name = powered and "No connected Bluetooth devices" or "Bluetooth is off" }
      end
      set_rows(values)
      busy = false
    end
    SBAR.exec(
      "/usr/bin/osascript " .. quote(helpers .. "airbuddy-batteries.applescript") .. " 2>/dev/null",
      function(out, status)
        merge(out, status)
        SBAR.exec("/bin/sh " .. quote(helpers .. "bluetooth-batteries.sh") .. " 2>/dev/null", function(out2, status2)
          merge(out2, status2)
          finish()
        end)
      end
    )
  end)
end

local ticker = SBAR.add("item", "bluetooth.popup_ticker", {
  drawing = false,
  updates = false,
  update_freq = 10,
})
ticker:subscribe("routine", refresh)
set_rows({ { name = "Loading Bluetooth devices…" } })
local close_popup = utils.hover_popup(bluetooth, nil, function(open)
  popup_open = open
  ticker:set({ updates = open })
  if open then
    refresh()
  end
end)

bluetooth:subscribe("mouse.clicked", function()
  close_popup()
  SBAR.exec("/usr/bin/osascript " .. quote(helpers .. "airbuddy-menu.applescript") .. " 2>&1", function(out, code)
    if code ~= 0 then
      print("AirBuddy menu failed (exit " .. tostring(code) .. "): " .. (out or "No output"))
    end
  end)
end)
