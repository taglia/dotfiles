-- Network bandwidth: two stacked upload/download rows, on the left after VPN.
-- Kept separate from the CPU/RAM/disk group so init.lua controls their placement.
local bandwidth_up = SBAR.add("item", "bandwidth.up", {
  position = "left",
  width = 0, -- Overlay the following item instead of consuming layout width.
  y_offset = 7,
  icon = { drawing = false },
  label = {
    font = { family = "Hack Nerd Font", style = "Regular", size = 12.0 },
    color = COLORS.mocha_red,
    string = "\u{2191} 0.0 B/s",
    padding_left = DEFAULT_ITEM.label.padding_right * 0.4,
    padding_right = 0,
  },
})

local bandwidth_down = SBAR.add("item", "bandwidth.down", {
  position = "left",
  update_freq = 2,
  y_offset = -7,
  icon = { drawing = false },
  label = {
    font = { family = "Hack Nerd Font", style = "Regular", size = 12.0 },
    color = COLORS.mocha_green,
    string = "\u{2193} 0.0 B/s",
    padding_left = DEFAULT_ITEM.label.padding_right * 0.4,
    padding_right = DEFAULT_ITEM.label.padding_right * 0.6,
  },
})

-- Human-readable bytes/s. Right-aligned width keeps the two lines from
-- jittering as the magnitude changes.
local function format_rate(bps)
  if bps < 1024 then
    return string.format("%5d B/s", math.floor(bps))
  elseif bps < 1024 * 1024 then
    return string.format("%5.1f KB/s", bps / 1024)
  elseif bps < 1024 * 1024 * 1024 then
    return string.format("%5.1f MB/s", bps / 1048576)
  else
    return string.format("%5.1f GB/s", bps / 1073741824)
  end
end

local bandwidth_prev_in, bandwidth_prev_out, bandwidth_prev_time

-- Read only the default interface's <Link#> counters; the per-address rows
-- repeat those counters and would multiply the rate if added together.
local function bandwidth_update()
  SBAR.exec(
    [[iface=$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')
netstat -ib 2>/dev/null | awk -v iface="$iface" '$1==iface && $3 ~ /<Link/ {print $7, $10}']],
    function(out)
      local inb, outb = out:match("(%d+)%s+(%d+)")
      inb = tonumber(inb) or 0
      outb = tonumber(outb) or 0
      local now = os.time()
      local dl, ul = 0, 0
      if bandwidth_prev_in and bandwidth_prev_time then
        local dt = now - bandwidth_prev_time
        if dt > 0 then
          -- Counter resets (interface changes/reboots) must not give negative rates.
          dl = math.max(0, inb - bandwidth_prev_in) / dt
          ul = math.max(0, outb - bandwidth_prev_out) / dt
        end
      end
      bandwidth_prev_in, bandwidth_prev_out, bandwidth_prev_time = inb, outb, now
      bandwidth_up:set({ label = { string = "\u{2191} " .. format_rate(ul) } })
      bandwidth_down:set({ label = { string = "\u{2193} " .. format_rate(dl) } })
    end
  )
end

-- A single tick refreshes both rows; both are clickable.
bandwidth_down:subscribe("routine", bandwidth_update)
for _, item in ipairs({ bandwidth_up, bandwidth_down }) do
  item:subscribe("mouse.clicked", function()
    SBAR.exec('open -a "Little Snitch Network Monitor"')
  end)
end

SBAR.add("bracket", "bandwidth.bracket", { "bandwidth.up", "bandwidth.down" }, {
  background = { drawing = true, border_width = 0, border_color = COLORS.transparent },
})

bandwidth_update()
