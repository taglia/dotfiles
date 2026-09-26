-- Visible only during a backup or when the last successful backup is overdue.
local utils = require("utils")
local helper_dir = utils.config_dir() .. "/helpers/"
local tm = SBAR.add("item", "timemachine", {
  position = "right",
  update_freq = 30,
  updates = true, -- Keep checking for overdue backups while the item is hidden.
  drawing = false,
  icon = {
    string = "󰑐",
    color = COLORS.mocha_overlay_1,
    font = { family = "Hack Nerd Font", style = "Regular" },
  },
  label = { drawing = false },
  popup = { align = "right" },
})

local rows = {}
for i = 1, 13 do
  rows[i] = SBAR.add("item", "timemachine.detail." .. i, {
    position = "popup." .. tm.name,
    icon = { drawing = false },
    label = {
      string = "",
      font = { family = "Hack Nerd Font", style = "Regular", size = 14.0 },
      align = "left",
      width = 430,
      padding_left = 14,
      padding_right = 14,
    },
    drawing = false,
  })
end

local popup_open, hovered = false, false
local status, history = {}, {}
local history_loading, status_loading = false, false
local history_failed = false
local phases = {
  Starting = "Starting",
  MountingBackupVol = "Connecting to backup disk",
  PreparingSourceVolumes = "Preparing",
  PreparingBackup = "Preparing",
  FindingChanges = "Finding changes",
  CalculatingChanges = "Calculating changes",
  PreBackupThinning = "Preparing (freeing space)",
  Copying = "Copying",
  Verifying = "Verifying",
  VerifyingBackup = "Verifying",
  Finishing = "Finishing",
  ThinningPostBackup = "Cleaning up",
  DeletingOldBackups = "Cleaning up",
  UnmountingBackupVol = "Ejecting backup disk",
}

local function parse(out)
  local values = {}
  for line in (out or ""):gmatch("[^\r\n]+") do
    local key, value = line:match("^([^\t]+)\t(.+)$")
    if key then
      values[key] = value
    end
  end
  return values
end

local function duration(seconds)
  if seconds < 60 then
    return "less than a minute"
  elseif seconds < 3600 then
    return math.floor(seconds / 60) .. " min"
  elseif seconds < 86400 then
    return math.floor(seconds / 3600) .. " h " .. math.floor(seconds % 3600 / 60) .. " min"
  end
  return math.floor(seconds / 86400) .. " d " .. math.floor(seconds % 86400 / 3600) .. " h"
end

-- Decimal units match macOS storage sizes. Choose each value's unit separately.
local function data_size(bytes)
  local units = { "B", "KB", "MB", "GB", "TB", "PB" }
  local unit = 1
  while bytes >= 1000 and unit < #units do
    bytes = bytes / 1000
    unit = unit + 1
  end
  return string.format(unit == 1 and "%.0f %s" or "%.1f %s", bytes, units[unit])
end

local function render()
  local epoch = tonumber(history.last_backup)
  local age = epoch and os.time() - epoch
  local warning = age ~= nil and age > 7 * 86400
  local running = status.running == "1"
  local visible = running or warning
  if not visible then
    popup_open, hovered = false, false
  end
  local phase = status.phase or "Status unavailable"
  local text = phases[phase] or phase:gsub("(%l)(%u)", "%1 %2")
  if phase == "Copying" and status.percent then
    text = "Copying " .. status.percent .. "%"
  end
  tm:set({
    drawing = visible,
    popup = { drawing = popup_open },
    icon = {
      color = warning and COLORS.mocha_peach or COLORS.mocha_green,
      padding_right = DEFAULT_ITEM.icon.padding_right * (hovered and 0.5 or 1),
    },
    label = { string = not running and warning and "Backup over a week old" or text, drawing = hovered },
  })
  -- Keep the hidden popup contents fresh too, ready for the next click and
  -- inspectable through SketchyBar's query API without opening the popup.
  local details = { "Status: " .. text }
  if epoch then
    table.insert(
      details,
      "Last successful: " .. (age >= 0 and (duration(age) .. " ago") or "Age unavailable (clock mismatch)")
    )
  else
    table.insert(details, history_loading and "Last successful: Loading…" or "Last successful: History unavailable")
  end
  if phase == "Copying" and tonumber(status.bytes) and tonumber(status.total_bytes) then
    table.insert(
      details,
      "Data: " .. data_size(tonumber(status.bytes)) .. " / " .. data_size(tonumber(status.total_bytes))
    )
  end
  if phase == "Copying" and tonumber(status.remaining) then
    table.insert(details, "Estimated remaining: " .. duration(tonumber(status.remaining)))
  end
  if epoch then
    table.insert(details, "Latest available backups:")
    for i = 1, 5 do
      local backup = tonumber(history["backup_" .. i])
      if backup then
        table.insert(details, "• " .. os.date("%Y-%m-%d %H:%M:%S %Z", backup))
      end
    end
  end
  if history_failed then
    table.insert(
      details,
      epoch and "History refresh failed — showing last known dates" or "History read failed — see SketchyBar log"
    )
  end
  if warning then
    table.insert(details, "Warning: Last successful backup is over a week old")
  end
  for i, row in ipairs(rows) do
    row:set({
      drawing = details[i] ~= nil,
      label = {
        string = details[i] or "",
        color = warning and i == #details and COLORS.mocha_peach or DEFAULT_ITEM.label.color,
      },
    })
  end
end

local function update_history()
  if history_loading then
    return
  end
  history_loading = true
  SBAR.exec("/bin/bash '" .. helper_dir .. "timemachine-history.sh'", function(out, code)
    history_loading = false
    local values = parse(out)
    if (code == nil or code == 0) and values.history == "ok" then
      history = values
      history_failed = false
    else
      if not history_failed then
        print("Time Machine history refresh failed (exit " .. tostring(code) .. "): " .. (out or "No output"))
      end
      history_failed = true -- Keep the last successfully read dates on transient failures.
    end
    render()
  end)
end

local function update()
  if not status_loading then
    status_loading = true
    SBAR.exec("bash '" .. helper_dir .. "timemachine-status.sh'", function(out)
      status_loading = false
      status = parse(out)
      render()
    end)
  end
  update_history()
end

tm:subscribe("mouse.entered", function()
  hovered = true
  render()
end)
tm:subscribe("mouse.exited", function()
  hovered = false
  render()
end)
tm:subscribe("mouse.clicked", function()
  popup_open = not popup_open
  tm:set({ popup = { drawing = popup_open } })
  if popup_open then
    update()
    render()
  end
end)
tm:subscribe({ "routine", "system_woke" }, update)
update()
