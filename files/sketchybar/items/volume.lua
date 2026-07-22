-- Volume indicator with two backends, chosen by probing the default output:
--
-- 1. Normal outputs (built-in speakers, Bluetooth headphones, ...): CoreAudio
--    via AppleScript (`get volume settings`). Click toggles the standard
--    software mute.
--
-- 2. HDMI/DisplayPort monitor audio (e.g. the Samsung C34J79x): macOS exposes
--    no volume/mute control for these outputs, and AppleScript returns
--    "missing value" — which doubles as the detection signal. In that case we
--    drive the monitor's own hardware volume/mute over DDC/CI via `m1ddc`
--    (on PATH via the Home Manager wrapper's `extraPackages`).
--
-- The C34J79x accepts DDC writes but returns garbage on reads, so the DDC
-- backend tracks last-known (volume, muted) itself in STATE_FILE.
--
-- "Mute" is implemented as VOLUME 0 (restore previous volume on unmute), NOT
-- as the display's hardware-mute command (VCP 0x8D): the C34J79x stays
-- hardware-muted until it receives an explicit mute-off, volume writes do not
-- clear it, and MonitorControl cannot read the mute state back — so a
-- hardware mute set here was impossible to clear from the keyboard, leaving
-- the screen silently stuck. With volume-0 semantics, ANY volume change from
-- ANY source (MonitorControl keys, this icon) restores sound. Unmute still
-- sends `mute off` first, in case the hardware mute was set elsewhere.
--
-- Remaining caveat (cosmetic): volume changes made by MonitorControl via the
-- keyboard bypass CoreAudio entirely (no `volume_change` event, unreadable
-- via DDC), so the icon cannot track them and may briefly show a stale state;
-- clicking the icon re-syncs.

local icons = {
  _100 = "􀊩",
  _66 = "􀊧",
  _33 = "􀊥",
  _10 = "􀊡",
  _0 = "􀊣",
  muted = "􀊣",
}

-- State for the DDC backend: "<volume> <muted:0|1>" on one line. Lives in
-- /tmp; a reboot resets it to the defaults, which is harmless since the
-- monitor's state after a reboot is unknown anyway.
local STATE_FILE = "/tmp/sketchybar-ddc-volume-" .. (os.getenv("USER") or "user")
local DEFAULT_VOLUME = 50

local volume_icon = SBAR.add("item", "volume_icon", {
  position = "right",
  label = { drawing = false },
  background = { drawing = false },
  -- Poll so the icon follows default-output switches (monitor <-> headphones),
  -- which do not reliably fire `volume_change`.
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

local function read_state()
  local file = io.open(STATE_FILE, "r")
  if file then
    local volume, muted = file:read("l"):match("^(%d+)%s+(%d)$")
    file:close()
    if volume then
      return tonumber(volume), muted == "1"
    end
  end
  return DEFAULT_VOLUME, false
end

local function write_state(volume, muted)
  local file = io.open(STATE_FILE, "w")
  if file then
    file:write(string.format("%d %d\n", volume, muted and 1 or 0))
    file:close()
  end
end

local function refresh()
  SBAR.exec("osascript -e 'output volume of (get volume settings)'", function(out)
    if (out or ""):match("missing value") then
      -- Default output has no software volume control: HDMI/DP monitor.
      local volume, muted = read_state()
      set_icon(volume, muted)
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

-- Toggle mute on click.
volume_icon:subscribe("mouse.clicked", function()
  SBAR.exec("osascript -e 'output volume of (get volume settings)'", function(out)
    if (out or ""):match("missing value") then
      -- Monitor backend, volume-0 mute semantics (see header comment).
      local volume, muted = read_state()
      if muted then
        -- Unmute: clear any hardware mute (may have been set elsewhere), then
        -- restore the tracked volume. Guard against a tracked volume of 0,
        -- which would restore silence.
        local restore = volume > 0 and volume or DEFAULT_VOLUME
        write_state(restore, false)
        SBAR.exec(
          string.format("m1ddc display 1 set mute off && m1ddc display 1 set volume %d", restore)
        )
        set_icon(restore, false)
      else
        -- Mute: keep the tracked volume for restore, set the monitor to 0.
        write_state(volume, true)
        SBAR.exec("m1ddc display 1 set volume 0")
        set_icon(volume, true)
      end
      return
    end
    SBAR.exec("osascript -e 'output muted of (get volume settings)'", function(muted_out)
      local muted = (muted_out or ""):match("true") ~= nil
      if muted then
        SBAR.exec("osascript -e 'set volume without output muted'")
      else
        SBAR.exec("osascript -e 'set volume with output muted'")
      end
    end)
  end)
end)
