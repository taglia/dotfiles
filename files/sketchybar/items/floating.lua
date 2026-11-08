-- Floating-window indicator.
--
-- A mauve pill right after the mode indicator while the focused window is
-- floating (out of the tiling tree), so an accidental alt-shift-f is obvious
-- instead of silently making the layout bindings look broken. Clicking the
-- pill tiles the window again.
--
-- `aerospace.toml` (modules/darwin/aerospace.nix) runs
--   <sketchybar> --trigger aerospace_focus_change
-- from on-focus-changed (window and workspace changes) and from the two
-- floating toggles (alt-shift-f, service-mode f), since toggling floating does
-- not change focus. On every event we RE-QUERY the focused window's layout,
-- the source of truth. With no focused window (empty workspace) list-windows
-- prints nothing and the pill hides. `aerospace` is on the wrapper's PATH via
-- programs.sketchybar.extraPackages.

SBAR.add("event", "aerospace_focus_change")

local floating = SBAR.add("item", "aerospace_floating", {
  position = "left",
  drawing = false,
  icon = {
    string = "󰖯", -- nf-md-window_restore
    font = { family = "Hack Nerd Font", style = "Bold", size = 18.0 },
    color = COLORS.black,
    padding_left = 9,
    padding_right = 4,
  },
  label = {
    string = "FLOATING",
    font = { family = "Hack Nerd Font", style = "Bold", size = 13.0 },
    color = COLORS.black,
    padding_left = 0,
    padding_right = 10,
  },
  -- Same pill geometry as the mode indicator (items/mode.lua).
  background = {
    color = COLORS.mocha_mauve,
    border_color = COLORS.mocha_mauve,
    border_width = 1,
    corner_radius = 10,
    height = 32,
    drawing = true,
  },
  -- Tile the window, then refresh: layout changes fire no AeroSpace callback.
  click_script = "aerospace layout tiling; sketchybar --trigger aerospace_focus_change",
})

local QUERY = "aerospace list-windows --focused --format '%{window-layout}'"

local function update(out, code)
  local layout = (code == 0 and type(out) == "string") and out:gsub("%s+", "") or ""
  floating:set({ drawing = layout == "floating" })
end

floating:subscribe("aerospace_focus_change", function()
  SBAR.exec(QUERY, update)
end)

-- Best-effort initial state at load.
SBAR.exec(QUERY, update)
