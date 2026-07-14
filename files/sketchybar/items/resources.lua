-- ==========================================================
-- CPU / RAM INDICATORS WITH TOP-PROCESS POPUPS
-- ==========================================================

local TOP_COUNT = 10
local POPUP_REFRESH_SECONDS = 3
local POPUP_ROW_WIDTH = 380

local core_count = 1 -- default fallback
local handle = io.popen("sysctl -n machdep.cpu.thread_count")
if handle then
	local result = handle:read("*a")
	core_count = tonumber(result) or 1
	handle:close()
end

local cpu = SBAR.add("item", "cpu", {
	position = "left",
	update_freq = 2,
	icon = {
		string = "􀧓",
		padding_right = DEFAULT_ITEM.icon.padding_right * 0.5,
	},
	label = { padding_right = DEFAULT_ITEM.label.padding_right * 0.6 },
	popup = { align = "left" },
})

local memory = SBAR.add("item", "memory", {
	position = "left",
	update_freq = 5,
	icon = {
		string = "􀫦",
		padding_right = DEFAULT_ITEM.icon.padding_right * 0.5,
	},
	label = { padding_right = DEFAULT_ITEM.label.padding_right * 0.6 },
	popup = { align = "left" },
})

local cpu_popup_open = false
local memory_popup_open = false

local function truncate(s, max_len)
	s = s or ""
	if #s <= max_len then
		return s
	end
	return s:sub(1, max_len - 1) .. "…"
end

local function basename(path)
	path = path or ""
	return path:match("([^/]+)$") or path
end

local function normalize_app_name(comm)
	comm = comm or ""

	-- App bundle paths are the nicest source of truth:
	-- /Applications/Orion.app/... -> Orion
	local app = comm:match("/([^/]+)%.app/") or comm:match("/([^/]+)%.app$")
	if app then
		return app
	end

	local name = basename(comm)
	name = name:gsub("%.app$", "")

	-- Browser tab/content helper processes. Orion, Safari, etc. often expose many
	-- WebKit child processes; group them back under the app name when possible.
	local webkit_app = name:match("WebContent%.([%w%._%-]+)$")
	if webkit_app then
		return webkit_app:gsub("%..*$", "")
	end

	return name
end

local function format_int_with_commas(value)
	local s = tostring(math.floor(value + 0.5))
	local sign, int = s:match("^(-?)(%d+)$")
	if not int then
		return s
	end
	local reversed = int:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	reversed = reversed:gsub("^,", "")
	return sign .. reversed
end

local function aggregate_top(out, value_formatter, name_width)
	local totals = {}
	for line in (out or ""):gmatch("[^\r\n]+") do
		local value, comm = line:match("([^\t]+)\t(.+)")
		value = tonumber(value)
		if value and comm then
			local name = normalize_app_name(comm)
			totals[name] = (totals[name] or 0) + value
		end
	end

	local entries = {}
	for name, value in pairs(totals) do
		table.insert(entries, { name = name, value = value })
	end
	table.sort(entries, function(a, b)
		return a.value > b.value
	end)

	local rows = {}
	for i = 1, math.min(TOP_COUNT, #entries) do
		local entry = entries[i]
		table.insert(rows, string.format("%s  %-" .. name_width .. "s", value_formatter(entry.value), truncate(entry.name, name_width)))
	end
	return rows
end

local function make_popup_rows(parent, prefix)
	local rows = {}
	for i = 1, TOP_COUNT do
		rows[i] = SBAR.add("item", prefix .. ".top." .. i, {
			position = "popup." .. parent.name,
			icon = { drawing = false },
			label = {
				string = "",
				font = { family = "Hack Nerd Font", style = "Regular", size = 14.0 },
				align = "left",
				width = POPUP_ROW_WIDTH,
				padding_left = 16,
				padding_right = 16,
			},
			drawing = false,
		})
	end
	return rows
end

local cpu_rows = make_popup_rows(cpu, "cpu")
local memory_rows = make_popup_rows(memory, "memory")

local function set_rows(rows, items)
	for i = 1, TOP_COUNT do
		local row = items[i]
		if row then
			rows[i]:set({ label = { string = row }, drawing = true })
		else
			rows[i]:set({ drawing = false })
		end
	end
end

-- ==========================================================
-- CPU INDICATOR
-- ==========================================================

local function cpu_update()
	SBAR.exec("ps -A -o %cpu | awk '{s+=$1} END {print s}'", function(total_load)
		local load = tonumber(total_load) or 0
		local used = math.floor(load / core_count)
		local color = (used > 80 and COLORS.red) or (used > 60 and COLORS.orange) or nil
		cpu:set({
			icon = { color = color or DEFAULT_ITEM.icon.color },
			label = { string = math.floor(used) .. "%", color = color or DEFAULT_ITEM.label.color },
		})
	end)
end

local function update_cpu_popup()
	if not cpu_popup_open then
		return
	end
	local cmd = [[ps axro pcpu,comm | awk 'NR>1 {value=$1; $1=""; sub(/^ +/, ""); printf "%.1f\t%s\n", value, $0}']]
	SBAR.exec(cmd, function(out)
		local rows = aggregate_top(out, function(value)
			return string.format("%6.1f%%", value)
		end, 28)
		set_rows(cpu_rows, rows)
	end)
end

cpu:subscribe("routine", function()
	cpu_update()
	update_cpu_popup()
end)

-- Defined with the popup ticker below; forward-declared so the click
-- handlers can start/stop it.
local sync_popup_ticker

cpu:subscribe("mouse.clicked", function()
	cpu_popup_open = not cpu_popup_open
	memory_popup_open = false
	memory:set({ popup = { drawing = false } })
	cpu:set({ popup = { drawing = cpu_popup_open } })
	if cpu_popup_open then
		update_cpu_popup()
	end
	sync_popup_ticker()
end)

-- ==========================================================
-- RAM / MEMORY INDICATOR
-- ==========================================================

local function memory_update()
	SBAR.exec("memory_pressure | grep 'System-wide memory free percentage:' | awk '{print 100-$5}'", function(result)
		local used = tonumber(result) or 0
		local color = (used > 80 and COLORS.red) or (used > 60 and COLORS.orange) or nil
		memory:set({
			icon = { color = color or DEFAULT_ITEM.icon.color },
			label = { string = math.floor(used) .. "%", color = color or DEFAULT_ITEM.label.color },
		})
	end)
end

local function update_memory_popup()
	if not memory_popup_open then
		return
	end
	local cmd = [[ps axmro rss,comm | awk 'NR>1 {value=$1/1024; $1=""; sub(/^ +/, ""); printf "%.1f\t%s\n", value, $0}']]
	SBAR.exec(cmd, function(out)
		local rows = aggregate_top(out, function(value)
			return string.format("%9s MB", format_int_with_commas(value))
		end, 28)
		set_rows(memory_rows, rows)
	end)
end

memory:subscribe("routine", function()
	memory_update()
	update_memory_popup()
end)

memory:subscribe("mouse.clicked", function()
	memory_popup_open = not memory_popup_open
	cpu_popup_open = false
	cpu:set({ popup = { drawing = false } })
	memory:set({ popup = { drawing = memory_popup_open } })
	if memory_popup_open then
		update_memory_popup()
	end
	sync_popup_ticker()
end)

-- ==========================================================
-- POPUP REFRESH TICKER
-- ==========================================================

-- Hidden item whose routine event refreshes the open popup. It only ticks
-- while a popup is visible: the click handlers toggle `updates` via
-- sync_popup_ticker() so nothing polls when both popups are closed.
local popup_ticker = SBAR.add("item", "resources.popup_ticker", {
	drawing = false,
	updates = false,
	update_freq = POPUP_REFRESH_SECONDS,
})

sync_popup_ticker = function()
	popup_ticker:set({ updates = (cpu_popup_open or memory_popup_open) })
end

popup_ticker:subscribe("routine", function()
	update_cpu_popup()
	update_memory_popup()
end)

-- ==========================================================
-- FINAL BRACKET (Unified Background)
-- ==========================================================

-- Wrap CPU and RAM into one bracket
SBAR.add("bracket", "resources.bracket", {
	"cpu",
	"memory",
}, {
	background = {
		drawing = true,
		border_width = 0,
		border_color = COLORS.transparent,
	},
})

-- ==========================================================
-- FORCE INITIAL UPDATES
-- ==========================================================
-- Call these immediately so we don't wait 2-5s for the first numbers
cpu_update()
memory_update()