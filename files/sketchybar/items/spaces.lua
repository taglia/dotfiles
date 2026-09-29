-- AeroSpace workspace indicator.
--
-- No macOS Spaces and no `rift` — workspaces come entirely from AeroSpace.
-- `aerospace.toml` runs, on every workspace change:
--   <sketchybar> --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE
-- (configured in modules/darwin/aerospace.nix, using the absolute nix store
-- path to sketchybar because aerospace's launchd daemon does not have the
-- Home Manager user PATH). We create one item per workspace on the left and
-- highlight the focused one. On every workspace-change event we RE-QUERY
-- `aerospace list-workspaces --focused` (the source of truth, robust on
-- multi-monitor setups) rather than trusting env.FOCUSED_WORKSPACE alone.
-- Hover lists the workspace's apps (deduplicated); leaving the item closes it.
-- Clicking still switches workspace. Window queries only run on hover.
-- `aerospace` is on the wrapper's PATH via programs.sketchybar.extraPackages.

local utils = require("utils")

local WORKSPACES = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }

-- Per-workspace icons. Only the active workspace shows its icon.
local WORKSPACE_ICONS = {
  ["1"] = "󰖟", -- browser / web
  ["2"] = "󰇮", -- mail
  ["3"] = "󰇮", -- mail
  ["4"] = "󰭹", -- chat
  ["5"] = "", -- terminal
  ["6"] = "􀢆", -- 3d apps
  ["7"] = "􀑪", -- music
  ["8"] = "󰈔", -- file
  ["9"] = "󰈔", -- file
}

SBAR.add("event", "aerospace_workspace_change")

local spaces = {}

local function highlight(focused)
  focused = focused and focused:gsub("%s+", "") or nil
  for _, entry in ipairs(spaces) do
    local is_focused = (focused == entry.sid)
    local workspace_icon = WORKSPACE_ICONS[entry.sid]
    entry.item:set({
      icon = { color = is_focused and COLORS.black or COLORS.mocha_text },
      label = {
        string = workspace_icon or "",
        color = is_focused and COLORS.black or COLORS.mocha_text,
        drawing = is_focused and workspace_icon ~= nil,
      },
      background = { drawing = is_focused },
    })

    -- Small slide-in/slide-out effect for the active workspace's icon.
    -- SketchyBar animates the label width; drawing is toggled above so the icon
    -- does not reserve space on inactive workspaces.
    SBAR.animate("tanh", 18.0, function()
      entry.item:set({ label = { width = (is_focused and workspace_icon ~= nil) and 22 or 0 } })
    end)
  end
end

for _, sid in ipairs(WORKSPACES) do
  local space = SBAR.add("item", "space." .. sid, {
    position = "left",
    icon = {
      string = sid,
      font = { family = "Hack Nerd Font", style = "Bold", size = 18.0 },
      color = COLORS.mocha_text,
      padding_left = 9,
      padding_right = 9,
    },
    label = {
      drawing = false,
      width = 0,
      font = { family = "Hack Nerd Font", style = "Bold", size = 17.0 },
      padding_left = 0,
      padding_right = 9,
    },
    background = {
      color = COLORS.mocha_yellow,
      border_color = COLORS.mocha_yellow,
      border_width = 1,
      corner_radius = 10,
      height = 32,
      drawing = false,
    },
    click_script = "aerospace workspace " .. sid,
    popup = { align = "left" },
  })
  table.insert(spaces, { item = space, sid = sid })

  -- Reuse rows as the app list grows/shrinks. Only app names are requested,
  -- not window titles; JSON preserves spaces and punctuation in names.
  local rows = {}
  local function set_rows(names)
    for i, app in ipairs(names) do
      if not rows[i] then
        rows[i] = SBAR.add("item", "space." .. sid .. ".app." .. i, {
          position = "popup." .. space.name,
          icon = { drawing = false },
          label = {
            font = { family = "Hack Nerd Font", style = "Regular", size = 14.0 },
            align = "left",
            padding_left = 14,
            padding_right = 14,
          },
        })
      end
      rows[i]:set({ drawing = true, label = { string = app } })
    end
    for i = #names + 1, #rows do
      rows[i]:set({ drawing = false })
    end
  end
  set_rows({ "Loading…" })

  local generation = 0
  utils.hover_popup(space, nil, function(open)
    generation = generation + 1
    if not open then
      return
    end
    local request = generation
    set_rows({ "Loading…" })
    SBAR.exec("aerospace list-windows --workspace " .. sid .. " --format '%{app-name}' --json", function(out, code)
      -- Ignore replies after exiting or reopening this workspace's popup.
      if request ~= generation then
        return
      end
      if code ~= 0 or type(out) ~= "table" then
        set_rows({ "Window list unavailable" })
        return
      end
      local names, seen = {}, {}
      for index, window in pairs(out) do
        if type(index) ~= "number" or type(window) ~= "table" or type(window["app-name"]) ~= "string" then
          set_rows({ "Window list unavailable" })
          return
        end
        local app = window["app-name"]
        if app ~= "" and not seen[app] then
          seen[app] = true
          names[#names + 1] = app
        end
      end
      table.sort(names, function(a, b)
        local lower_a, lower_b = a:lower(), b:lower()
        return lower_a == lower_b and a < b or lower_a < lower_b
      end)
      set_rows(#names > 0 and names or { "No windows" })
    end)
  end)
end

-- One subscription (on the first space item) handles all workspace-change
-- events: re-query the actual focused workspace and highlight accordingly.
spaces[1].item:subscribe("aerospace_workspace_change", function()
  SBAR.exec("aerospace list-workspaces --focused", highlight)
end)

-- Best-effort initial highlight at load.
SBAR.exec("aerospace list-workspaces --focused", highlight)
