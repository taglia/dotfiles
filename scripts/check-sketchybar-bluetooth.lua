-- Pure Lua tests: no Bluetooth, AppleEvents, or GUI interaction.
local items, pending = {}, {}
SBAR = {
  add = function(_, name, config)
    local item = { name = name, config = config, callbacks = {} }
    function item:set(values)
      for k, v in pairs(values) do
        if type(v) == "table" then
          self.config[k] = self.config[k] or {}
          for key, value in pairs(v) do
            self.config[k][key] = value
          end
        else
          self.config[k] = v
        end
      end
    end
    function item:subscribe(event, callback)
      self.callbacks[event] = callback
    end
    items[name] = item
    return item
  end,
  exec = function(command, callback)
    pending[#pending + 1] = { command = command, callback = callback }
  end,
}
package.loaded.utils = nil
package.path = "files/sketchybar/?.lua;" .. package.path
dofile("files/sketchybar/items/bluetooth.lua")
local item = items.bluetooth
local ticker = items["bluetooth.popup_ticker"]
local function reply(value, code)
  local request = table.remove(pending, 1)
  assert(request, "expected pending request")
  request.callback(value, code or 0)
end
local function row(i)
  return items["bluetooth.device." .. i].config
end
local function data(devices, state)
  return {
    SPBluetoothDataType = {
      { controller_properties = { controller_state = state or "attrib_on" }, device_connected = devices },
    },
  }
end
assert(#pending == 0 and not ticker.config.updates, "no idle polling")
item.callbacks["mouse.entered"]()
assert(item.config.popup.drawing and ticker.config.updates and #pending == 1)
ticker.callbacks.routine()
assert(#pending == 1, "no overlapping requests")
reply(data({
  { Zebra = { device_address = "AA:BB", device_batteryLevelMain = "20%" } },
  { Alpha = { device_address = "CC:DD" } },
  { Mouse = { device_address = "D0:03:4B:DD:81:7A" } },
  { Plain = { device_address = "EE:EE" } },
}))
assert(#pending == 1)
reply("aa-bb\t45%\ncc:dd\tL 80% · R 90%\nff:ee\t100%\n")
assert(#pending == 1, "IO registry helper runs after AirBuddy")
assert(pending[1].command:match("bluetooth%-batteries%.sh"))
reply("d0-03-4b-dd-81-7a\t44%\ncc-dd\t1%\n")
assert(row(1).icon.string == "Alpha" and row(1).label.string == "L 80% · R 90%", "AirBuddy beats IO registry")
assert(row(2).icon.string == "Mouse" and row(2).label.string == "44%", "IO registry fills in HID batteries")
assert(row(3).icon.string == "Plain" and row(3).label.drawing == false, "no reading: no battery column")
assert(row(3).icon.width == 380 and row(1).icon.width == 240, "battery rows leave room for the right column")
assert(row(1).label.align == "right" and row(1).icon.align == "left")
assert(row(4).icon.string == "Zebra" and row(4).label.string == "45%")
assert(not items["bluetooth.device.5"], "AirBuddy-only devices are excluded")
item.callbacks["mouse.exited"]()
assert(not item.config.popup.drawing and not ticker.config.updates)
ticker.callbacks.routine()
assert(#pending == 0)
item.callbacks["mouse.entered"]()
reply(data({ { Zebra = { device_batteryLevelMain = "20%" } } }))
reply("", 1)
reply("", 1)
assert(row(1).icon.string == "Zebra" and row(1).label.string == "20%", "macOS fallback on helper failures")
assert(not row(2).drawing)
ticker.callbacks.routine()
reply(data({}))
reply("")
reply("")
assert(row(1).icon.string == "No connected Bluetooth devices" and row(1).label.drawing == false)
ticker.callbacks.routine()
reply(data({}, "attrib_off"))
reply("")
reply("")
assert(row(1).icon.string == "Bluetooth is off")
ticker.callbacks.routine()
reply("bad output", 1)
assert(row(1).icon.string == "Bluetooth status unavailable")
ticker.callbacks.routine()
assert(#pending == 1, "probe recovers after failure")
item.callbacks["mouse.exited"]()
reply(data({}))
reply("")
reply("")
assert(not item.config.popup.drawing, "late replies must not reopen popup")
item.callbacks["mouse.entered"]()
item.callbacks["mouse.clicked"]()
assert(not item.config.popup.drawing and not ticker.config.updates)
assert(pending[2].command:match("airbuddy%-menu%.applescript"))
print("Bluetooth popup tests passed")
