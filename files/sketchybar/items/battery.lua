local battery = SBAR.add("item", "battery", {
  position = "right",
  update_freq = 120,
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
    local found, _, charge = batt_info:find("(%d+)%%")

    if found then
      local charge_num = tonumber(charge)

      -- Power state. `pmset -g batt` prints either "Now drawing from
      -- 'AC Power'" or, on newer macOS, "AC attached" on the battery line.
      -- The battery line distinguishes "charging" / "not charging" /
      -- "charged", which is what lets us tell the plugged-in sub-states
      -- apart (e.g. AlDente holding a cap reports "not charging").
      local is_plugged = batt_info:find("AC Power") ~= nil or batt_info:find("AC attached") ~= nil
      local is_full = charge_num >= 100 or batt_info:find("charged") ~= nil
      local is_charging = is_plugged
        and not is_full
        and batt_info:find("not charging") == nil
        and batt_info:find("charging") ~= nil

      local color
      local icon

      if is_plugged then
        icon = "􂬹"
        if is_full then
          color = COLORS.mocha_green
        elseif is_charging then
          color = COLORS.mocha_peach
        else
          -- Plugged in but neither full nor actively charging (AlDente cap,
          -- or "AC attached; not charging"). Keep the previous plugged color.
          color = (charge_num < 20) and COLORS.mocha_yellow or DEFAULT_ITEM.icon.color
        end
      else
        -- On battery: icon + color track the charge level.
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
    end
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
