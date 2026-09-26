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
for i = 1, 6 do
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
  if not popup_open then
    return
  end

  local details = { "Status: " .. text, "Destination: " .. (history.destination or "Unavailable") }
  if epoch then
    table.insert(details, "Last successful: " .. os.date("%Y-%m-%d %H:%M:%S %Z", epoch))
    table.insert(details, "Age: " .. (age >= 0 and (duration(age) .. " ago") or "Unavailable (clock mismatch)"))
    if history.last_destination and history.last_destination ~= history.destination then
      details[2] = "Last backup destination: " .. history.last_destination
    end
  else
    table.insert(details, history_loading and "Last successful: Loading…" or "Last successful: History unavailable")
  end
  if phase == "Copying" and tonumber(status.remaining) then
    table.insert(details, "Estimated remaining: " .. duration(tonumber(status.remaining)))
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
  SBAR.exec("osascript -l JavaScript '" .. helper_dir .. "timemachine-history.js' 2>/dev/null", function(out)
    history_loading = false
    history = parse(out)
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
