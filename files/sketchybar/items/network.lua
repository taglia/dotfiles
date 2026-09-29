-- Two stacked items, like the calendar. Uses the unmodified wifi-unredactor;
-- launch its app explicitly to set up the Location Services grant.
local utils = require("utils")
local width = 100
local network = SBAR.add("item", "network", {
  position = "left",
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
  position = "left",
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
local details = {}
for _, kind in ipairs({ "wifi", "wired" }) do
  details[kind] = SBAR.add("item", "network.detail." .. kind, {
    position = "popup." .. network.name,
    icon = { drawing = false },
    label = {
      string = kind == "wifi" and "Wi-Fi: Checking…" or "Wired: Checking…",
      font = { size = 14.0 },
      align = "left",
      padding_left = 14,
      padding_right = 14,
    },
  })
end

local function text_or(value, fallback)
  return type(value) == "string" and value ~= "" and value or fallback
end

local function addresses(ip, gateway)
  return text_or(ip, "No IP") .. " [" .. text_or(gateway, "Gateway unavailable") .. "]"
end

local function wired_detail(result)
  if result.wired == false then
    return "Wired: Disconnected"
  elseif result.wired ~= true then
    return "Wired: Status unavailable"
  end
  local links = type(result.wired_links) == "table" and result.wired_links or {}
  local entries = {}
  for _, link in ipairs(links) do
    if type(link) == "table" then
      local prefix = #links > 1 and (text_or(link.interface, "Interface") .. ": ") or ""
      entries[#entries + 1] = prefix
        .. text_or(link.speed, "Speed unavailable")
        .. " — "
        .. addresses(link.ip, link.gateway)
    end
  end
  if #entries == 0 then
    entries[1] = "Speed unavailable — " .. addresses(nil, nil)
  end
  return "Wired: " .. table.concat(entries, "; ")
end

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
      text = "Disconnected"
    elseif result.status == "connected" then
      text = text .. " — " .. addresses(result.wifi_ip, result.wifi_gateway)
    end
    local wired = result.wired == true
    network:set({
      label = {
        string = (disconnected and "󰤭" or "󰤨") .. "  " .. (wired and "󰈁" or "󰈂"),
        color = disconnected and not wired and COLORS.mocha_overlay_1 or COLORS.mocha_text,
      },
    })
    -- Keep the lower item's layout space even when no SSID is shown.
    name:set({ label = { string = disconnected and "" or (ssid and truncate(ssid) or "Unknown") } })
    details.wifi:set({ label = { string = "Wi-Fi: " .. text } })
    details.wired:set({ label = { string = wired_detail(result) } })
  end)
end

utils.hover_popup(network, { network, name })
for _, item in ipairs({ network, name }) do
  item:subscribe("mouse.clicked", function()
    SBAR.exec("open 'x-apple.systempreferences:com.apple.preference.network'")
  end)
end
network:subscribe({ "routine", "wifi_change", "system_woke" }, update)
update()
