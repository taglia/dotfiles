-- Volume indicator. Display-only; all volume/mute control now lives in
-- FineTune (menu bar app, installed via Homebrew — see
-- modules/darwin/homebrew.nix).
--
-- Icon state is read from CoreAudio via AppleScript (`get volume settings`),
-- which reflects the actual default output for built-in speakers, AirPods,
-- Bluetooth headphones, etc. HDMI/DisplayPort monitor outputs (e.g. the
-- Samsung C34J79x) have no software volume exposed to CoreAudio, so
-- AppleScript returns "missing value"; in that case the icon falls back to a
-- neutral state — the authoritative volume UI is FineTune, which drives the
-- monitor over DDC (software volume-0 mute semantics, F10–F12 media keys).
--
-- Interaction:
--   left-click  → toggle the FineTune popup by sending its global "Toggle
--                 FineTune Popup" hotkey (⌃⌥⌘-s, bound in FineTune →
--                 Settings → Shortcuts). FineTune's popup only opens on raw
--                 mouse events / its own synthetic events (FluidMenuBarExtra
--                 LocalEventMonitor), so an Accessibility AXPress on the menu
--                 bar item does nothing — the hotkey is the reliable path.
--                 Requires Accessibility permission for SketchyBar (keystroke
--                 synthesis); falls back to a CoreAudio software-mute toggle
--                 if FineTune is not running.
--   right-click → toggle CoreAudio software mute (built-in/BT outputs).
--
-- Polls every 5s (`update_freq`) to follow default-output switches, which
-- do not reliably fire `volume_change`.

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
  update_freq = 5,
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
    if (out or ""):match("missing value") then
      -- HDMI/DP monitor output: no software volume visible to CoreAudio.
      -- Show a neutral icon; FineTune has the real state (DDC).
      set_icon(50, false)
      return
    end
    local volume = tonumber(out) or 0
    SBAR.exec("osascript -e 'output muted of (get volume settings)'", function(muted_out)
      local muted = (muted_out or ""):match("true") ~= nil
      set_icon(volume, muted)
    end)
  end)
end

volume_icon:subscribe("volume_change", refresh)
volume_icon:subscribe("routine", refresh)

-- Initialize without waiting for the first volume_change event.
refresh()

local function toggle_coreaudio_mute()
  SBAR.exec("osascript -e 'output muted of (get volume settings)'", function(muted_out)
    local muted = (muted_out or ""):match("true") ~= nil
    if muted then
      SBAR.exec("osascript -e 'set volume without output muted'")
    else
      SBAR.exec("osascript -e 'set volume with output muted'")
    end
  end)
end

local function open_finetune()
  -- FineTune's popup ignores accessibility (AXPress) clicks on its menu bar
  -- item — it only reacts to raw mouse events via a LocalEventMonitor — so we
  -- synthesize its global "Toggle FineTune Popup" hotkey instead. Requires
  -- Accessibility permission for SketchyBar (osascript keystrokes are
  -- otherwise auto-denied with error 1002).
  SBAR.exec("pgrep -qx FineTune && osascript -e 'tell application \"System Events\" to keystroke \"s\" using {command down, option down, shift down}' || echo not-running",
    function(out)
      if (out or ""):match("not%-running") then
        toggle_coreaudio_mute()
      end
    end
  )
end

volume_icon:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "right" then
    toggle_coreaudio_mute()
  else
    open_finetune()
  end
end)
