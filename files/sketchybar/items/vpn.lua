-- VPN symbol and detail rows embedded in the network widget.
local utils = require("utils")

return function(network)
  local vpn = SBAR.add("item", "network.vpn", {
    position = "left",
    width = 0,
    y_offset = 7,
    update_freq = 60,
    icon = { drawing = false },
    label = {
      string = "􀎥",
      color = COLORS.mocha_red,
      font = { family = "Hack Nerd Font", style = "Regular", size = 16.0 },
      align = "right",
      width = 100,
      padding_left = 0,
      padding_right = 24,
    },
  })

  local rows = {}
  for i = 1, 3 do
    rows[i] = SBAR.add("item", "network.detail.vpn." .. i, {
      position = "popup." .. network.name,
      icon = { drawing = false },
      label = {
        string = i == 1 and "VPN: Checking…" or "",
        font = { size = 14.0 },
        align = "left",
        padding_left = 14,
        padding_right = 14,
      },
      drawing = i == 1,
    })
  end

  local script = utils.config_dir() .. "/helpers/vpn-status.sh"
  local pending = false
  local function update()
    if pending then
      return
    end
    pending = true
    SBAR.exec("bash '" .. script .. "'", function(out)
      pending = false
      local values = {}
      for line in (type(out) == "string" and out or ""):gmatch("[^\r\n]+") do
        local key, value = line:match("([^\t]+)\t(.+)")
        if key and value then
          values[key] = value
        end
      end
      local connected = values.status == "connected"
      local details = { "VPN: " .. (values.name or (connected and "Connected" or "Disconnected")) }
      if values.tailscale then
        table.insert(details, "Tailscale: " .. values.tailscale)
      end
      if values.exit then
        table.insert(details, "Exit node: " .. values.exit)
      end
      vpn:set({
        label = {
          string = connected and "􀎡" or "􀎥",
          color = connected and COLORS.mocha_text or COLORS.mocha_red,
        },
      })
      for i, row in ipairs(rows) do
        row:set({ label = { string = details[i] or "" }, drawing = details[i] ~= nil })
      end
    end)
  end

  vpn:subscribe({ "routine", "system_woke", "wifi_change" }, update)
  update()
  return { item = vpn, update = update }
end
