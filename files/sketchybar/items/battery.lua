local battery = SBAR.add("item", "battery", {
  position = "right",
  update_freq = 30,
  icon = {
    font = {
      family = "Hack Nerd Font",
      style = "Regular",
    },
  },
  label = { drawing = true }, -- Percentage always visible (no slideover)
})

local function battery_update()
  SBAR.exec("pmset -g batt", function(batt_info)
    -- Ignore external batteries/UPS devices and use the Mac's internal
    -- battery line for charge and charging state.
    local battery_line = batt_info:match("%-InternalBattery[^\n]*")
    local charge = battery_line and battery_line:match("(%d+)%%")
    local source = batt_info:match("Now drawing from '([^']+)'\n")

    if not battery_line or not charge or not source then
      return
    end

    local charge_num = tonumber(charge)
    local is_plugged = source == "AC Power"
    local is_full = charge_num >= 100 or battery_line:find(";%s*charged[%s;]") ~= nil
    local is_charging = is_plugged
      and not is_full
      and battery_line:find(";%s*not charging[%s;]") == nil
      and battery_line:find(";%s*charging[%s;]") ~= nil

    local color
    local icon

    if is_plugged then
      icon = "􂬹"
      if is_full then
        color = COLORS.mocha_green
      elseif is_charging then
        color = COLORS.mocha_peach
      else
        -- AC power without active charging, such as an AlDente charge cap.
        color = (charge_num < 20) and COLORS.mocha_yellow or DEFAULT_ITEM.icon.color
      end
    else
      -- On battery, including AlDente discharge mode while the cable remains
      -- connected: icon and color track the internal battery level.
      if charge_num > 90 then
        icon = "󰁹"
      elseif charge_num > 60 then
        icon = "󰂀"
      elseif charge_num > 40 then
        icon = "󰁾"
      elseif charge_num > 10 then
        icon = "󰁼"
      else
        icon = "󰂎"
      end

      if charge_num < 10 then
        color = COLORS.mocha_red
      elseif charge_num < 30 then
        color = COLORS.mocha_peach
      else
        color = COLORS.mocha_text
      end
    end

    -- Label is always drawn, so always use the tightened icon padding.
    local icon_padding = DEFAULT_ITEM.icon.padding_right * 0.5

    battery:set({
      icon = {
        string = icon,
        color = color,
        padding_right = icon_padding,
      },
      label = { string = charge .. "%", color = color, drawing = true },
    })
  end)
end

-- AlDente is a menu-bar app. Opening the app bundle directly shows its popup;
-- the registered `aldente://` URL scheme exists but appears to be a no-op here.
-- If AlDente ever documents a dedicated "show popup" command, replace this.
battery:subscribe("mouse.clicked", function()
  SBAR.exec("open -b com.apphousekitchen.aldente-pro")
end)

battery:subscribe({ "routine", "power_source_change", "system_woke" }, battery_update)

-- Populate immediately instead of waiting up to update_freq for the first
-- routine tick.
battery_update()
