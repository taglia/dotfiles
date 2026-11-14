-- AeroSpace binding-mode indicator, doubling as the way back from
-- `enable off`.
--
-- Hidden while AeroSpace is in its default "main" mode. When another mode is
-- active (the "service" mode entered with alt-shift-semicolon), a peach pill
-- with the mode's icon and name appears right after the workspace numbers,
-- like vim's -- INSERT -- hint, so a forgotten mode is never a mystery.
--
-- When tiling is suspended (`t` in service mode runs `enable toggle`), a red
-- "TILING OFF" pill appears instead, and clicking it runs `aerospace enable
-- on`. That click is the intended way back: a disabled AeroSpace intercepts
-- no keys at all, so no binding can re-enable it.
--
-- `aerospace.toml` runs, on every mode change (modules/darwin/aerospace.nix):
--   <sketchybar> --trigger aerospace_mode_change
-- Disabling counts as a mode change (the active mode becomes none), as does
-- re-enabling. AeroSpace passes no variable with the new mode to that
-- callback, so on every event we RE-QUERY `aerospace list-modes --current`
-- (the source of truth, also robust to a missed event). While disabled the
-- server rejects every command but `enable` with exit code 2 (server.swift,
-- EXIT_CODE_TWO), which is how the disabled state is detected:
-- `list-modes --current` would otherwise report "main". Any other failure
-- means the server is not reachable (AeroSpace still starting, waiting for
-- its Accessibility grant, or gone): a yellow "NO AEROSPACE" pill says so,
-- and the probe repeats every few seconds until it answers, because no
-- mode-change event will come while nothing is running. At login that pill
-- normally lasts a few seconds; if it stays, AeroSpace needs attention (its
-- Accessibility grant is lost whenever the Nix store path changes). Without
-- the retry a probe failing at login mislabelled the whole session as
-- "TILING OFF" (2026-11-14). `aerospace` is on the wrapper's PATH via
-- programs.sketchybar.extraPackages.

local MODES = {
  service = { icon = "󰒓", label = "SERVICE" }, -- nf-md-cog
}
-- Any mode without an entry above.
local FALLBACK_ICON = "󰌌" -- nf-md-keyboard
local DISABLED = { icon = "󰏤", label = "TILING OFF" } -- nf-md-pause
local UNREACHABLE = { icon = "󰀦", label = "NO AEROSPACE" } -- nf-md-alert

SBAR.add("event", "aerospace_mode_change")

local mode = SBAR.add("item", "aerospace_mode", {
  position = "left",
  drawing = false,
  icon = {
    string = "",
    font = { family = "Hack Nerd Font", style = "Bold", size = 18.0 },
    color = COLORS.black,
    padding_left = 9,
    padding_right = 4,
  },
  label = {
    string = "",
    font = { family = "Hack Nerd Font", style = "Bold", size = 13.0 },
    color = COLORS.black,
    padding_left = 0,
    padding_right = 10,
  },
  -- Same pill geometry as the focused workspace (items/spaces.lua). Colour
  -- says which state: peach = binding mode, red = tiling off, yellow =
  -- AeroSpace unreachable.
  background = {
    color = COLORS.mocha_peach,
    border_color = COLORS.mocha_peach,
    border_width = 1,
    corner_radius = 10,
    height = 32,
    drawing = true,
  },
})

-- Hidden item whose routine event re-probes while the last probe failed.
local RETRY_SECONDS = 5
local retry = SBAR.add("item", "aerospace_mode.retry", {
  drawing = false,
  updates = false,
  update_freq = RETRY_SECONDS,
})

local function update(out, code)
  retry:set({ updates = code ~= 0 })
  if code == 2 then
    mode:set({
      drawing = true,
      icon = { string = DISABLED.icon },
      label = { string = DISABLED.label },
      background = { color = COLORS.mocha_red, border_color = COLORS.mocha_red },
      click_script = "aerospace enable on",
    })
    return
  end
  if code ~= 0 then
    -- Server unreachable: not the same as tiling switched off, so a distinct
    -- colour and no re-enable click; the ticker keeps probing.
    mode:set({
      drawing = true,
      icon = { string = UNREACHABLE.icon },
      label = { string = UNREACHABLE.label },
      background = { color = COLORS.mocha_yellow, border_color = COLORS.mocha_yellow },
      click_script = "",
    })
    return
  end
  local current = type(out) == "string" and out:gsub("%s+", "") or ""
  if current == "" or current == "main" then
    mode:set({ drawing = false, click_script = "" })
    return
  end
  local style = MODES[current] or { icon = FALLBACK_ICON, label = current:upper() }
  mode:set({
    drawing = true,
    icon = { string = style.icon },
    label = { string = style.label },
    background = { color = COLORS.mocha_peach, border_color = COLORS.mocha_peach },
    click_script = "",
  })
end

local function probe()
  SBAR.exec("aerospace list-modes --current", update)
end

mode:subscribe("aerospace_mode_change", probe)
retry:subscribe("routine", probe)

-- Initial state at load; retried by the ticker until AeroSpace answers.
probe()
