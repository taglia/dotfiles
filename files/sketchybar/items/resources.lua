-- ==========================================================
-- CPU INDICATOR
-- ==========================================================

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
	label = { padding_right = 0 },
})

local function cpu_update()
	SBAR.exec("ps -A -o %cpu | awk '{s+=$1} END {print s}'", function(total_load)
		local load = tonumber(total_load) or 0
		local used = math.floor(load / core_count)
		local color = (used > 80 and 0xffff4444) or (used > 60 and 0xffffa500) or nil
		cpu:set({
			icon = { color = color or DEFAULT_ITEM.icon.color },
			label = { string = math.floor(used) .. "%", color = color or DEFAULT_ITEM.label.color },
		})
	end)
end

cpu:subscribe("routine", cpu_update)

-- ==========================================================
-- RAM / MEMORY INDICATOR
-- ==========================================================

local memory = SBAR.add("item", "memory", {
	position = "left",
	update_freq = 5,
	icon = {
		string = "􀫦",
		padding_right = DEFAULT_ITEM.icon.padding_right * 0.5,
	},
	label = { padding_right = 0 },
})

local function memory_update()
	SBAR.exec("memory_pressure | grep 'System-wide memory free percentage:' | awk '{print 100-$5}'", function(result)
		local used = tonumber(result) or 0
		local color = (used > 80 and 0xffff4444) or (used > 60 and 0xffffa500) or nil
		memory:set({
			icon = { color = color or DEFAULT_ITEM.icon.color },
			label = { string = math.floor(used) .. "%", color = color or DEFAULT_ITEM.label.color },
		})
	end)
end

memory:subscribe("routine", memory_update)

-- ==========================================================
-- FINAL BRACKET (Unified Background)
-- ==========================================================

-- Wrap CPU and RAM into one bracket
SBAR.add("bracket", "resources.bracket", {
	"cpu",
	"memory",
}, {
	background = { drawing = true },
})

-- ==========================================================
-- FORCE INITIAL UPDATES
-- ==========================================================
-- Call these immediately so we don't wait 2-5s for the first numbers
cpu_update()
memory_update()
