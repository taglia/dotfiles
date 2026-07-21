local icons = {
  _100 = "􀊩",
  _66 = "􀊧",
  _33 = "􀊥",
  _10 = "􀊡",
  _0 = "􀊣",
  muted = "􀊣",
}

local volume_icon = SBAR.add("item", "volume_icon", {
  position = "right",
  label = { drawing = false },
  background = { drawing = false },
})

local function set_icon(volume, muted)
  local icon = icons._0
  if muted then
    icon = icons.muted
  elseif volume > 60 then
    icon = icons._100
  elseif volume > 30 then
    icon = icons._66
  elseif volume > 10 then
    icon = icons._33
  elseif volume > 0 then
    icon = icons._10
  end
  volume_icon:set({ icon = icon })
end

local function refresh()
  SBAR.exec("osascript -e 'output volume of (get volume settings)'", function(out)
    local volume = tonumber(out) or 0
    SBAR.exec("osascript -e 'output muted of (get volume settings)'", function(muted_out)
      local muted = (muted_out or ""):match("true") ~= nil
      set_icon(volume, muted)
    end)
  end)
end

volume_icon:subscribe("volume_change", refresh)

-- Initialize without waiting for the first volume_change event.
refresh()

-- Toggle mute on click.
volume_icon:subscribe("mouse.clicked", function()
  SBAR.exec("osascript -e 'output muted of (get volume settings)'", function(muted_out)
    local muted = (muted_out or ""):match("true") ~= nil
    if muted then
      SBAR.exec("osascript -e 'set volume without output muted'")
    else
      SBAR.exec("osascript -e 'set volume with output muted'")
    end
  end)
end)
