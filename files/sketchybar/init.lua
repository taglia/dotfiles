require("globals")
-- 1. Setup Bar and Defaults
SBAR.begin_config() -- Pauses redraw for faster loading

-- Left Side: AeroSpace workspace indicator (no macOS Spaces, no rift) + the
-- resources widget (CPU/RAM). aerospace.toml triggers
-- `aerospace_workspace_change` on workspace switch (see
-- modules/darwin/aerospace.nix); see items/spaces.lua. resources.lua places
-- its own items on the left.
require("items.spaces")
require("items.resources")

-- Right Side (Order: Right -> Left)
require("items.calendar")
require("items.battery")
require("items.timemachine")
require("items.volume")
require("items.vpn")
-- Frontmost-app icon is required LAST on the right so it is the leftmost
-- right-side item (immediately left of the VPN indicator).
require("items.front_app")

-- 4. Finalize
SBAR.end_config()

-- nix adaptation: the event loop is started by the entry file (sketchybarrc)
-- after its own end_config(). Calling SBAR.event_loop() here blocked
-- require("init") from returning, which left sketchybarrc's begin_config()
-- unbalanced and the bar hidden (drawing=off). Removed so sketchybarrc's
-- end_config()/event_loop() run and the config session closes properly.
