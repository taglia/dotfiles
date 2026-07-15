-- High-contrast SketchyBar palette.
-- Values are 0xAARRGGBB (alpha in the high byte).
--
-- The translucent "liquid glass" colors looked reasonable in hex but rendered as
-- dark gray on darker gray on this MBP. This palette intentionally favors
-- readability over subtlety: opaque near-black bar, pure-white text, and a
-- bright yellow focused-workspace pill with black text.
local colors = {}

-- Common
colors.white = 0xffffffff
colors.black = 0xff000000
colors.transparent = 0x00000000

-- Catppuccin Mocha (https://catppuccin.com/palette/)
-- Names match the palette page with spaces -> _ and all lowercase.
-- Prefixed with mocha_ to avoid colliding with the common colors above
-- (red, yellow, white, black).
colors.mocha_rosewater = 0xfff5e0dc
colors.mocha_flamingo = 0xfff2cdcd
colors.mocha_pink = 0xfff5c2e7
colors.mocha_mauve = 0xffcba6f7
colors.mocha_red = 0xfff38ba8
colors.mocha_maroon = 0xffeba0ac
colors.mocha_peach = 0xfffab387
colors.mocha_yellow = 0xfff9e2af
colors.mocha_green = 0xffa6e3a1
colors.mocha_teal = 0xff94e2d5
colors.mocha_sky = 0xff89dceb
colors.mocha_sapphire = 0xff74c7ec
colors.mocha_blue = 0xff89b4fa
colors.mocha_lavender = 0xffb4befe
colors.mocha_text = 0xffcdd6f4
colors.mocha_subtext_1 = 0xffbac2de
colors.mocha_subtext_0 = 0xffa6adc8
colors.mocha_overlay_2 = 0xff9399b2
colors.mocha_overlay_1 = 0xff7f849c
colors.mocha_overlay_0 = 0xff6c7086
colors.mocha_surface_2 = 0xff585b70
colors.mocha_surface_1 = 0xff45475a
colors.mocha_surface_0 = 0xff313244
colors.mocha_base = 0xff1e1e2e
colors.mocha_mantle = 0xff181825
colors.mocha_crust = 0xff11111b

return colors

