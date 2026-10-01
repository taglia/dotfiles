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
    string = "􀙇  󰈂",
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
local titles = { wifi = "Wi-Fi", wired = "Wired", public = "Public IP" }
for _, kind in ipairs({ "wifi", "wired", "public" }) do
  details[kind] = SBAR.add("item", "network.detail." .. kind, {
    position = "popup." .. network.name,
    icon = { drawing = false },
    label = {
      string = titles[kind] .. ": Checking…",
      font = { size = 14.0 },
      align = "left",
      padding_left = 14,
      padding_right = 14,
    },
  })
end

-- Keep external lookups separate from local interface/SSID probes. Only fetch
-- while the popup is open, at most once per minute (including failed requests).
local popup_open = false
local public_pending, last_public_check = false, nil
local public_generation = 0
local PUBLIC_REFRESH_SECONDS = 60
local PUBLIC_IP_COMMAND = "/usr/bin/curl -q --ipv4 --noproxy '*' --fail --silent"
  .. " --connect-timeout 3 --max-time 5 --max-filesize 64 https://api.ipify.org"

local function public_ipv4(out)
  if type(out) ~= "string" or #out > 64 then
    return nil
  end
  local a, b, c, d = out:match("^%s*(%d+)%.(%d+)%.(%d+)%.(%d+)%s*$")
  if not a then
    return nil
  end
  local parts = { a, b, c, d }
  for _, part in ipairs(parts) do
    if #part > 3 or tonumber(part) > 255 then
      return nil
    end
  end
  return table.concat(parts, ".")
end

local function update_public_ip()
  local now = os.time()
  if
    public_pending
    or (last_public_check and now >= last_public_check and now - last_public_check < PUBLIC_REFRESH_SECONDS)
  then
    return
  end
  public_pending, last_public_check = true, now
  local generation = public_generation
  details.public:set({ label = { string = "Public IP: Checking…" } })
  SBAR.exec(PUBLIC_IP_COMMAND, function(out, code)
    public_pending = false
    -- A network change while curl was running invalidates that response.
    if generation ~= public_generation then
      if popup_open then
        update_public_ip()
      end
      return
    end
    local ip = code == 0 and public_ipv4(out) or nil
    details.public:set({ label = { string = "Public IP: " .. (ip or "Unavailable") } })
  end)
end

local function invalidate_public_ip()
  public_generation = public_generation + 1
  last_public_check = nil
  details.public:set({ label = { string = "Public IP: Checking…" } })
  if popup_open then
    update_public_ip()
  end
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
        string = (disconnected and "􀙈" or "􀙇") .. "  " .. (wired and "󰈁" or "󰈂"),
        color = disconnected and not wired and COLORS.mocha_overlay_1 or COLORS.mocha_text,
      },
    })
    -- Keep the lower item's layout space even when no SSID is shown.
    name:set({ label = { string = disconnected and "" or (ssid and truncate(ssid) or "Unknown") } })
    details.wifi:set({ label = { string = "Wi-Fi: " .. text } })
    details.wired:set({ label = { string = wired_detail(result) } })
  end)
end

utils.hover_popup(network, { network, name }, function(open)
  popup_open = open
  if open then
    update_public_ip()
  end
end)
for _, item in ipairs({ network, name }) do
  item:subscribe("mouse.clicked", function()
    SBAR.exec("open 'x-apple.systempreferences:com.apple.preference.network'")
  end)
end
network:subscribe("routine", function()
  update()
  if popup_open then
    update_public_ip()
  end
end)
network:subscribe({ "wifi_change", "system_woke" }, function()
  update()
  invalidate_public_ip()
end)
update()
