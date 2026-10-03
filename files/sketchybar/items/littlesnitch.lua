-- Immediately after VPN on the left. The root LaunchDaemon publishes only
-- preferences; this item never invokes sudo or Little Snitch's privileged CLI.
local utils = require("utils")
local indicator = SBAR.add("item", "littlesnitch", {
  position = "left",
  update_freq = 5,
  updates = true, -- Continue probing when the healthy-state indicator is hidden.
  icon = {
    string = "􀙥",
    font = { family = "SF Pro", style = "Bold", size = 26.0 },
    color = COLORS.mocha_yellow,
    padding_left = 8,
    padding_right = 8,
  },
  label = { drawing = false },
  background = { drawing = false },
  popup = { align = "left" },
})
local detail = SBAR.add("item", "littlesnitch.detail", {
  position = "popup." .. indicator.name,
  icon = { drawing = false },
  label = {
    string = "Little Snitch: checking…",
    font = { size = 14.0 },
    padding_left = 14,
    padding_right = 14,
  },
})
local help = SBAR.add("item", "littlesnitch.help", {
  position = "popup." .. indicator.name,
  drawing = false,
  icon = { drawing = false },
  label = {
    string = "Settings > Security > Allow access via Terminal",
    font = { size = 14.0 },
    padding_left = 14,
    padding_right = 14,
  },
})
local modes = { [0] = "Alert", [1] = "Silent Allow", [2] = "Silent Deny" }
local pending = false
local close_popup
local function update()
  if pending then
    return
  end
  pending = true
  SBAR.exec("/bin/cat /var/run/dotfiles-littlesnitch/status.json 2>/dev/null", function(status, code)
    pending = false
    local fresh = code == 0
      and type(status) == "table"
      and status.version == 1
      and type(status.checked_at) == "number"
      and status.checked_at <= os.time()
      and os.time() - status.checked_at <= 60
    local warning, unknown, message = false, true, "Little Snitch: status unavailable — check the status service"
    if code == 0 and type(status) == "table" and not fresh then
      message = "Little Snitch: status stale or invalid — waiting for a fresh check"
    end
    help:set({ drawing = fresh and status.error_kind == "cli_disabled" })
    if fresh then
      local mode_ok = type(status.mode) == "number" and modes[status.mode] ~= nil
      local filter_ok = type(status.filter_enabled) == "boolean"
      -- A known unsafe preference still wins if the other probe failed.
      warning = status.mode == 1 or status.filter_enabled == false
      unknown = not mode_ok or not filter_ok
      local issues = {}
      if status.filter_enabled == false then
        issues[#issues + 1] = "network filter disabled"
      end
      if status.mode == 1 then
        issues[#issues + 1] = "Silent Allow enabled"
      end
      if status.error_kind == "cli_disabled" then
        unknown = true
        issues[#issues + 1] = "CLI not enabled"
      elseif unknown then
        issues[#issues + 1] = "unable to read preferences"
      end
      message = "Little Snitch: "
        .. (#issues > 0 and table.concat(issues, "; ") or (modes[status.mode] .. " — network filter enabled"))
    end
    indicator:set({
      drawing = warning or unknown,
      icon = { color = warning and COLORS.mocha_red or COLORS.mocha_yellow },
    })
    if not warning and not unknown then
      close_popup()
    end
    detail:set({ label = { string = message } })
  end)
end
indicator:subscribe({ "routine", "system_woke" }, update)
close_popup = utils.hover_popup(indicator, nil, function(open)
  if open then
    update()
  end
end)
indicator:subscribe("mouse.clicked", function()
  close_popup()
  SBAR.exec('/usr/bin/open -a "Little Snitch"')
end)
update()
