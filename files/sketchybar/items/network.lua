-- Two stacked items, like the calendar. Uses the unmodified wifi-unredactor;
-- launch its app explicitly to set up the Location Services grant.
local width = 100
local network = SBAR.add("item", "network", {
  position = "right",
  width = 0,
  y_offset = 7,
  update_freq = 30,
  icon = { drawing = false },
  label = {
    string = "󰤨  󰈂",
    font = { family = "Hack Nerd Font", style = "Regular", size = 16.0 },
    align = "center",
    width = width,
    padding_left = 4,
    padding_right = 4,
  },
  popup = { align = "center" },
})
local name = SBAR.add("item", "network.ssid", {
  position = "right",
  y_offset = -8,
  icon = { drawing = false },
  label = {
    string = "…",
    font = { family = "Hack Nerd Font", style = "Regular", size = 11.0 },
    align = "center",
    width = width,
    padding_left = 4,
    padding_right = 4,
  },
})
local detail = SBAR.add("item", "network.detail", {
  position = "popup." .. network.name,
  icon = { drawing = false },
  label = { string = "Checking network…", font = { size = 14.0 }, padding_left = 14, padding_right = 14 },
})

local function truncate(ssid)
  -- Count UTF-8 code points, not bytes; never cut through an encoded character.
  local count = utf8.len(ssid)
  if count and count > 10 then
    return ssid:sub(1, utf8.offset(ssid, 11) - 1) .. "…"
  end
  return ssid
end

local pending = false
local function update()
  if pending then
    return
  end
  pending = true
  SBAR.exec("sketchybar-network-status", function(result)
    pending = false
    if type(result) ~= "table" then
      result = { status = "unknown", reason = "Wi-Fi status unavailable" }
    end
    local disconnected = result.status == "disconnected"
    local ssid = type(result.ssid) == "string" and result.ssid ~= "" and result.ssid or nil
    local text = ssid or result.reason or "SSID unavailable — check Location Services"
    if disconnected then
      text = "Wi-Fi disconnected"
    end
    local wired = result.wired == true
    text = text .. "  |  Wired: " .. (wired and "connected" or "disconnected")
    network:set({
      label = {
        string = (disconnected and "󰤭" or "󰤨") .. "  " .. (wired and "󰈁" or "󰈂"),
        color = disconnected and not wired and COLORS.mocha_overlay_1 or COLORS.mocha_text,
      },
    })
    -- Keep the lower item's layout space even when no SSID is shown.
    name:set({ label = { string = disconnected and "" or (ssid and truncate(ssid) or "Unknown") } })
    detail:set({ label = { string = text } })
  end)
end

for _, item in ipairs({ network, name }) do
  item:subscribe("mouse.entered", function()
    network:set({ popup = { drawing = true } })
  end)
  item:subscribe("mouse.exited", function()
    network:set({ popup = { drawing = false } })
  end)
  item:subscribe("mouse.clicked", function()
    SBAR.exec("open 'x-apple.systempreferences:com.apple.preference.network'")
  end)
end
network:subscribe("mouse.exited.global", function()
  network:set({ popup = { drawing = false } })
end)
network:subscribe({ "routine", "wifi_change", "system_woke" }, update)
update()
