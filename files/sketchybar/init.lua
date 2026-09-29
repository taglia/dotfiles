require("globals")
-- 1. Setup Bar and Defaults
SBAR.begin_config() -- Pauses redraw for faster loading

-- Left Side (Order: Left -> Right)
-- AeroSpace triggers aerospace_workspace_change; see modules/darwin/aerospace.nix.
require("items.spaces")
require("items.network")
require("items.bandwidth")
require("items.vpn")

-- Right Side (Order: Right -> Left)
require("items.calendar")
require("items.volume")
require("items.battery")
require("items.resources") -- Creates disk -> RAM -> CPU; on screen: CPU -> RAM -> disk.
require("items.front_app")
-- Backup indicators (Time Machine, CCC) are required LAST on the right so
-- they are the leftmost right-side items (left of the front-app icon) when
-- visible (running backups, plus overdue Time Machine backups).
require("items.timemachine")
require("items.ccc")

-- 4. Finalize
SBAR.end_config()

-- nix adaptation: the event loop is started by the entry file (sketchybarrc)
-- after its own end_config(). Calling SBAR.event_loop() here blocked
-- require("init") from returning, which left sketchybarrc's begin_config()
-- unbalanced and the bar hidden (drawing=off). Removed so sketchybarrc's
-- end_config()/event_loop() run and the config session closes properly.
