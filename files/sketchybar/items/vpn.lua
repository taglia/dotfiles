-- VPN status indicator.
-- Shows a compact "VPN" marker on the right. Bright green means connected; gray
-- means disconnected. Click for details. Tailscale gets special handling for
-- exit-node status when the `tailscale` CLI is present.
--
-- The status probe lives in helpers/vpn-status.sh (shellcheck-ed by CI) so this
-- file just parses its tab-separated output. The helper path is resolved
-- relative to this file's own location, so it works wherever the config tree
-- is installed (the HM wrapper copies the directory verbatim into
-- ~/.config/sketchybar/).

local vpn = SBAR.add("item", "vpn", {
  position = "right",
  -- VPN state changes rarely and the poll shells out to scutil (and possibly
  -- tailscale), so a slow tick is enough; system_woke and clicks refresh it
  -- at the moments it actually changes.
  update_freq = 60,
  icon = {
    string = "VPN",
    font = { family = "Hack Nerd Font", style = "Bold", size = DEFAULT_ITEM.icon.font.size * 0.82 },
    padding_left = DEFAULT_ITEM.icon.padding_left,
    padding_right = DEFAULT_ITEM.icon.padding_right,
  },
  label = { drawing = false },
  background = {
    drawing = true,
    color = COLORS.mocha_mantle,
    border_color = COLORS.mocha_overlay_1,
  },
  popup = { align = "right" },
})

local rows = {}
for i = 1, 3 do
  rows[i] = SBAR.add("item", "vpn.detail." .. i, {
    position = "popup." .. vpn.name,
    icon = { drawing = false },
    label = {
      string = "",
      font = { family = "Hack Nerd Font", style = "Regular", size = 14.0 },
      align = "left",
      width = 250,
      padding_left = 14,
      padding_right = 14,
    },
    drawing = false,
  })
end

local source = debug.getinfo(1, "S").source
local this_file = source:sub(1, 1) == "@" and source:sub(2) or source
local config_dir = this_file:match("^(.*)/items/[^/]+$") or (os.getenv("HOME") .. "/.config/sketchybar")
local vpn_status_script = config_dir .. "/helpers/vpn-status.sh"

local vpn_popup_open = false
local last_details = { "VPN: disconnected" }

local function set_rows(details)
  for i = 1, #rows do
    if details[i] then
      rows[i]:set({ label = { string = details[i] }, drawing = true })
    else
      rows[i]:set({ drawing = false })
    end
  end
end

local function update_vpn()
  SBAR.exec("bash '" .. vpn_status_script .. "'", function(out)
    local values = {}
    for line in (out or ""):gmatch("[^\r\n]+") do
      local key, value = line:match("([^\t]+)\t(.+)")
      if key and value then
        values[key] = value
      end
    end

    local connected = values.status == "connected"
    local name = values.name or (connected and "Connected" or "Disconnected")
    last_details = { "VPN: " .. name }
    if values.tailscale and values.tailscale ~= "" then
      table.insert(last_details, "Tailscale: " .. values.tailscale)
    end
    if values.exit and values.exit ~= "" then
      table.insert(last_details, "Exit node: " .. values.exit)
    end

    vpn:set({
      icon = { color = connected and COLORS.mocha_green or COLORS.mocha_overlay_1 },
      background = {
        color = COLORS.mocha_mantle,
        border_color = connected and COLORS.mocha_green or COLORS.mocha_overlay_1,
      },
    })

    if vpn_popup_open then
      set_rows(last_details)
    end
  end)
end

vpn:subscribe({ "routine", "system_woke" }, update_vpn)

vpn:subscribe("mouse.clicked", function()
  vpn_popup_open = not vpn_popup_open
  vpn:set({ popup = { drawing = vpn_popup_open } })
  if vpn_popup_open then
    set_rows(last_details)
    update_vpn()
  end
end)

update_vpn()
