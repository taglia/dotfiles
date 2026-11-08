-- AeroSpace binding-mode indicator.
--
-- Hidden while AeroSpace is in its default "main" mode. When another mode is
-- active (the "service" mode entered with alt-shift-semicolon), a pill with
-- the mode's icon and name appears right after the workspace numbers, like
-- vim's -- INSERT -- hint, so a forgotten mode is never a mystery.
--
-- `aerospace.toml` runs, on every mode change (modules/darwin/aerospace.nix):
--   <sketchybar> --trigger aerospace_mode_change
-- AeroSpace passes no variable with the new mode to that callback, so on every
-- event we RE-QUERY `aerospace list-modes --current` (the source of truth,
-- also robust to a missed event). `aerospace` is on the wrapper's PATH via
-- programs.sketchybar.extraPackages.

local MODES = {
  service = { icon = "󰒓", label = "SERVICE" }, -- nf-md-cog
}
-- Any mode without an entry above.
local FALLBACK_ICON = "󰌌" -- nf-md-keyboard

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

local function update(out)
  local current = type(out) == "string" and out:gsub("%s+", "") or ""
  if current == "" or current == "main" then
    mode:set({ drawing = false })
    return
  end
  local style = MODES[current] or { icon = FALLBACK_ICON, label = current:upper() }
  mode:set({
    drawing = true,
    icon = { string = style.icon },
    label = { string = style.label },
  })
end

mode:subscribe("aerospace_mode_change", function()
  SBAR.exec("aerospace list-modes --current", update)
end)

-- Best-effort initial state at load.
SBAR.exec("aerospace list-modes --current", update)
