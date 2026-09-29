-- Run from the repository root: lua scripts/check-sketchybar-spaces.lua
-- Mock AeroSpace and SketchyBar; no real windows, probes, or workspace switches.
package.path = "files/sketchybar/?.lua;" .. package.path
COLORS = { black = "black", mocha_text = "white", mocha_yellow = "yellow" }
local items, events, requests, commands = {}, {}, {}, {}
local focused = "2\n"
SBAR = {
  add = function(kind, name, config)
    if kind == "event" then
      events[name] = true
      return
    end
    assert(not items[name], "Duplicate item: " .. name)
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
    function item:subscribe(names, callback)
      for _, event in ipairs(type(names) == "table" and names or { names }) do
        self.callbacks[event] = callback
      end
    end
    items[name] = item
    return item
  end,
  animate = function(_, _, callback)
    callback()
  end,
  exec = function(command, callback)
    commands[#commands + 1] = command
    if command == "aerospace list-workspaces --focused" then
      callback(focused, 0)
      return
    end
    local sid = command:match("^aerospace list%-windows %-%-workspace (%d+) %-%-format '%%{app%-name}' %-%-json$")
    assert(sid, "Unexpected command: " .. command)
    requests[#requests + 1] = { sid = sid, callback = callback }
  end,
}
dofile("files/sketchybar/items/spaces.lua")
local function space(sid)
  return items["space." .. sid]
end
local function fire(sid, event)
  assert(space(sid).callbacks[event], "Missing " .. event)()
end
local function visible(sid)
  return space(sid).config.popup.drawing == true
end
local function labels(sid)
  local names = {}
  local i = 1
  while items["space." .. sid .. ".app." .. i] do
    local row = items["space." .. sid .. ".app." .. i].config
    assert(row.position == "popup.space." .. sid)
    if row.drawing then
      names[#names + 1] = row.label.string
    end
    i = i + 1
  end
  return table.concat(names, "\n")
end
local function reply(index, value, code)
  requests[index].callback(value, code or 0)
end
assert(events.aerospace_workspace_change)
assert(#requests == 0 and #commands == 1) -- No window queries until hover.
for sid = 1, 9 do
  local item = space(sid)
  assert(item.config.position == "left" and item.config.icon.string == tostring(sid))
  assert(item.config.click_script == "aerospace workspace " .. sid)
  assert(item.callbacks["mouse.entered"] and item.callbacks["mouse.exited"])
  assert(not item.callbacks["mouse.exited.global"])
end
assert(space(2).config.background.drawing and space(2).config.label.drawing)
assert(not space(1).config.background.drawing and not space(1).config.label.drawing)

fire(2, "mouse.entered")
assert(visible(2) and labels(2) == "Loading…" and requests[1].sid == "2")
fire(2, "mouse.entered")
assert(#requests == 1) -- Repeated enters while open do not duplicate the query.
reply(1, {
  { ["app-name"] = "Visual Studio Code" },
  { ["app-name"] = "Safari" },
  { ["app-name"] = "Activity Monitor" },
  { ["app-name"] = "Safari" },
  { ["app-name"] = "Reader | Preview" },
})
assert(labels(2) == "Activity Monitor\nReader | Preview\nSafari\nVisual Studio Code")
assert(space(2).config.label.drawing) -- Hover does not replace the active icon.
local old_second_row = items["space.2.app.2"]
fire(2, "mouse.exited")
assert(not visible(2))
fire(2, "mouse.entered")
assert(labels(2) == "Loading…")
reply(2, {})
assert(labels(2) == "No windows" and not old_second_row.config.drawing)
assert(items["space.2.app.2"] == old_second_row) -- Reuse surplus rows, don't leak items.

fire(3, "mouse.entered")
assert(visible(3) and not visible(2))
fire(3, "mouse.exited")
reply(3, { { ["app-name"] = "Late app" } })
assert(not visible(3) and labels(3) == "Loading…")
fire(3, "mouse.entered")
fire(3, "mouse.exited")
fire(3, "mouse.entered")
reply(5, { { ["app-name"] = "Fresh app" } })
reply(4, { { ["app-name"] = "Stale app" } })
assert(visible(3) and labels(3) == "Fresh app")

for _, fixture in ipairs({
  { "AeroSpace unavailable", 1 },
  { "not JSON", 0 },
  { { error = "wrong shape" }, 0 },
  { { { ["window-title"] = "Not an app name" } }, 0 },
}) do
  fire(8, "mouse.entered")
  reply(#requests, fixture[1], fixture[2])
  assert(labels(8) == "Window list unavailable" and visible(8))
  fire(8, "mouse.exited")
  assert(not visible(8))
end

-- Each callback must retain its own workspace ID, not the final loop value.
for sid = 1, 9 do
  fire(sid, "mouse.entered")
  assert(requests[#requests].sid == tostring(sid))
  reply(#requests, { { ["app-name"] = "App " .. sid }, { ["app-name"] = "App " .. sid } })
  assert(labels(sid) == "App " .. sid)
end
local count = #requests
focused = "9\n"
fire(1, "aerospace_workspace_change")
assert(space(9).config.background.drawing and not space(2).config.background.drawing)
assert(#requests == count) -- Focus changes do not poll every workspace's windows.
fire(9, "mouse.exited")
assert(not visible(9))
print("SketchyBar workspace hover checks passed")
