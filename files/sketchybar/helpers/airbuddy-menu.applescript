-- Click the actual AirBuddy menu-bar item, not show dashboard/show devices
-- (those scripting commands open a different UI). Requires Accessibility for
-- the calling app. AirBuddy must keep its native menu-bar icon enabled and
-- General > Click Menu Bar icon to must be Show list of devices.
-- Tested live with AirBuddy 3.0.3.
if application "AirBuddyHelper" is not running then error "AirBuddy is not running"

with timeout of 5 seconds
	tell application "System Events"
		tell process "AirBuddyHelper"
			-- Locate a status item, never an ordinary application menu.
			repeat with bar in menu bars
				repeat with menuItem in menu bar items of bar
					if subrole of menuItem is "AXMenuExtra" and (name of actions of menuItem) contains "AXPress" then
						perform action "AXPress" of menuItem
						return
					end if
				end repeat
			end repeat
		end tell
	end tell
end timeout
error "AirBuddy menu-bar icon not found; enable its icon in AirBuddy settings"
