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
-- server rejects every command but `enable` with exit code 2, which is how
-- the disabled state is detected: `list-modes --current` would otherwise
-- report "main". `aerospace` is on the wrapper's PATH via
-- programs.sketchybar.extraPackages.

local MODES = {
  service = { icon = "󰒓", label = "SERVICE" }, -- nf-md-cog
}
-- Any mode without an entry above.
local FALLBACK_ICON = "󰌌" -- nf-md-keyboard
local DISABLED = { icon = "󰏤", label = "TILING OFF" } -- nf-md-pause

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
  -- Same pill geometry as the focused workspace (items/spaces.lua), in peach
  -- so the two cannot be confused.
  background = {
    color = COLORS.mocha_peach,
    border_color = COLORS.mocha_peach,
    border_width = 1,
    corner_radius = 10,
    height = 32,
    drawing = true,
  },
})

local function update(out, code)
  if code ~= 0 then
    mode:set({
      drawing = true,
      icon = { string = DISABLED.icon },
      label = { string = DISABLED.label },
      background = { color = COLORS.mocha_red, border_color = COLORS.mocha_red },
      click_script = "aerospace enable on",
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

mode:subscribe("aerospace_mode_change", function()
  SBAR.exec("aerospace list-modes --current", update)
end)

-- Best-effort initial state at load.
SBAR.exec("aerospace list-modes --current", update)
