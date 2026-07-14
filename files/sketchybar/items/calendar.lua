-- Calendar / world clock.
-- Shows local time + date. On click, shows a popup with the current time in
-- several timezones, ordered chronologically (earliest first). Does NOT open
-- Calendar.app.

local ZONES = {
	{ name = "Paris", tz = "Europe/Paris" },
	{ name = "London", tz = "Europe/London" },
	{ name = "UTC", tz = "UTC" },
	{ name = "New York", tz = "America/New_York" },
	{ name = "San Francisco", tz = "America/Los_Angeles" },
}

local right_padding = 28 -- keep clear of macOS/SoundSource activity dot

-- 1. THE TIME (Top Line)
local cal_time = SBAR.add("item", "cal.time", {
	position = "right",
	width = 0, -- Stack logic
	y_offset = 7,
	label = {
		font = { size = DEFAULT_ITEM.label.font.size },
		align = "right",
		padding_right = right_padding,
		padding_left = DEFAULT_ITEM.icon.padding_left,
	},
	popup = { align = "right" },
})

-- 2. THE DATE (Bottom Line)
local cal_date = SBAR.add("item", "cal.date", {
	position = "right",
	y_offset = -10,
	label = {
		font = { size = DEFAULT_ITEM.label.font.size * 0.78 },
		color = COLORS.secondary_accent,
		padding_right = right_padding,
		padding_left = DEFAULT_ITEM.icon.padding_left,
	},
	icon = { drawing = false },
})

-- 3. WORLD-CLOCK POPUP ITEMS (reused for the sorted rows)
local popup_items = {}
for i = 1, #ZONES do
	local item = SBAR.add("item", "cal.zone." .. i, {
		position = "popup." .. cal_time.name,
		icon = { drawing = false },
		label = {
			string = "",
			font = { family = "Hack Nerd Font", style = "Regular", size = 15.0 },
			align = "left",
			width = 360,
			padding_left = 14,
			padding_right = 14,
		},
		drawing = false,
	})
	table.insert(popup_items, item)
end

-- 4. UPDATE LOCAL TIME/DATE
local function update_calendar()
	cal_date:set({ label = { string = os.date("%a %b %d"):upper() } })
	cal_time:set({ label = { string = os.date("%H:%M") } })
end

local function day_offset_label(day_key)
	local today_key = os.date("%Y%m%d")
	if day_key < today_key then
		return " [-1]"
	elseif day_key > today_key then
		return " [+1]"
	end
	return ""
end

-- 5. BUILD THE WORLD-CLOCK POPUP (query all zones, sort chronologically)
local function build_popup()
	local cmd = ""
	for _, z in ipairs(ZONES) do
		-- sort_key is timezone-local date+time, so previous/next-day zones sort
		-- correctly across midnight. Display is 12h time with AM/PM plus a day
		-- offset relative to the local date when needed, e.g. "11:24 PM [-1]".
		cmd = cmd
			.. "printf '%s\\t%s\\t%s\\t%s\\n' '"
			.. z.name
			.. "' \"$(TZ="
			.. z.tz
			.. " date +%Y%m%d%H%M)\" \"$(TZ="
			.. z.tz
			.. " date '+%I:%M %p')\" \"$(TZ="
			.. z.tz
			.. " date +%Y%m%d)\";"
	end
	SBAR.exec(cmd, function(out)
		local rows = {}
		for line in (out or ""):gmatch("[^\r\n]+") do
			local nm, sort_key, tm, day_key = line:match("([^\t]+)\t([0-9]+)\t([^\t]+)\t([0-9]+)")
			if nm and sort_key and tm and day_key then
				table.insert(rows, {
					name = nm,
					sort_key = sort_key,
					time = tm:gsub("^0", ""),
					day_key = day_key,
				})
			end
		end
		table.sort(rows, function(a, b)
			return a.sort_key < b.sort_key
		end) -- earliest first => chronological, including across midnight
		for i, row in ipairs(rows) do
			local p = popup_items[i]
			if p then
				local display_time = row.time .. day_offset_label(row.day_key)
				p:set({
					label = { string = string.format("%-16s %18s", row.name, display_time) },
					drawing = true,
				})
			end
		end
		for i = #rows + 1, #popup_items do
			popup_items[i]:set({ drawing = false })
		end
	end)
end

-- 6. SUBSCRIPTIONS
cal_time:subscribe({ "routine", "system_woke" }, update_calendar)
cal_time:set({ update_freq = 30 })

-- Click: refresh times and toggle the popup. query() can return nil/partial
-- data during a reload, so don't trust its shape.
local function on_click()
	local q = cal_time:query()
	local current = q and q.popup and q.popup.drawing
	if current == "off" then
		build_popup()
	end
	cal_time:set({ popup = { drawing = (current == "off") } })
end
cal_time:subscribe("mouse.clicked", on_click)
cal_date:subscribe("mouse.clicked", on_click)

update_calendar()