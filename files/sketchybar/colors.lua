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
colors.red = 0xffff5555
colors.orange = 0xffffb86c
colors.charging = 0xffffd700

-- Bar / text
colors.bar_color = 0xff05070a
colors.accent_color = 0xffffffff
colors.secondary_accent = 0xff67e8f9
colors.disabled_color = 0xffd1d5db

-- Item backgrounds / popups
colors.background = 0xff111827
colors.background_border = 0xff4b5563
colors.popup_background = 0xff05070a
colors.popup_border = 0xffffffff

-- Workspace indicator
colors.workspace_focused_bg = 0xffffd166
colors.workspace_focused_fg = 0xff000000
colors.workspace_unfocused_fg = 0xffffffff

return colors