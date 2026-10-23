-- Optional enrichment for the authoritative macOS Bluetooth connection list.
-- Snapshot reads avoid one AppleEvent per property/device. No UI or connections
-- are changed. Requires AirBuddy's Enable AppleScript for automation setting.
-- Output: Bluetooth address<TAB>battery description, one device per line.
if application "AirBuddyHelper" is not running then return ""

with timeout of 5 seconds
	tell application "AirBuddyHelper"
		set snapshots to live device snapshots
		set output to ""
		repeat with d in snapshots
			set batteryText to ""
			repeat with b in battery snapshots of d
				if unreliable of b is false then
					set part to position of b
					set prefix to ""
					if part is left bud then set prefix to "L "
					if part is right bud then set prefix to "R "
					if part is charging case then set prefix to "Case "
					-- Combined buds duplicate the individual left/right readings.
					if part is not combined buds then
						set percentage to round (level of b)
						if percentage ≥ 0 and percentage ≤ 100 then
							if batteryText is not "" then set batteryText to batteryText & " · "
							set batteryText to batteryText & prefix & percentage & "%"
							if charging state of b is charging then set batteryText to batteryText & " +"
						end if
					end if
				end if
			end repeat
			if address of d is not "" and batteryText is not "" then
				set output to output & (address of d) & tab & batteryText & linefeed
			end if
		end repeat
		return output
	end tell
end timeout
