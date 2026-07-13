# SketchyBar config

This directory is the SketchyBar status bar configuration. It is intentionally
kept as a self-contained tree, separate from the rest of the dotfiles, so it is
easily identifiable as "the SketchyBar config" and not mixed with hand-written
Nix code or other app configs.

The only Nix-side references to it are:
- `modules/home/sketchybar.nix` — the Home Manager module that installs this
  whole directory verbatim into `~/.config/sketchybar/` via
  `programs.sketchybar.config.source` (recursive), wires the launchd agent, and
  puts `aerospace` on the wrapper's `PATH` (`extraPackages`) for the workspace
  indicator.
- one line in `flake.nix` (`hosts.mbp.modules`) that imports that module.
- `modules/darwin/aerospace.nix` — `exec-on-workspace-change` triggers the
  `aerospace_workspace_change` sketchybar event consumed by `items/spaces.lua`,
  using the absolute nix store path to `sketchybar` (aerospace's launchd daemon
  does not see the Home Manager user PATH).

Everything SketchyBar-related lives here or in those two modules.

## Origin

Originally vendored from [hajiboy95/dotfiles](https://github.com/hajiboy95/dotfiles)
(`.config/sketchybar`), then trimmed and re-worked for this setup. The
`pre-sketchybar` git tag marks the repo state before SketchyBar was added.

## What's here

A high-contrast bar (height 38, sized for the MacBook Pro notch/menu-bar
area): opaque near-black background, pure-white text, and a bright focused
workspace pill.
- **Left**: AeroSpace workspace indicator (`items/spaces.lua`) — one item per
  workspace 1-9, focused workspace highlighted. No macOS Spaces, no `rift`.
  Resources (`items/resources.lua`) — CPU and RAM usage.
- **Right**: calendar (`items/calendar.lua`) — local time + date; click for a
  world-clock popup (Paris, London, UTC, New York, San Francisco) ordered
  chronologically with AM/PM and day offsets. battery (`items/battery.lua`),
  VPN indicator (`items/vpn.lua`), and volume (`items/volume.lua`).

Colors live in `colors.lua` (explicit high-contrast palette: opaque near-black
bar, white foreground, bright yellow focused workspace).

## Local modifications (vs. upstream)

- Uses an explicit high-contrast palette (hardcoded, no theme switching, no
  `active_theme.txt`).
- Removed Spotify, the theme picker, Borders, the menus widget, the control
  center, Pomodoro timers, the network part of resources, clipboard, separators/brackets, and the
  `icon_map`.
- Replaced the `rift`-based spaces widget with an AeroSpace event-driven
  workspace indicator that re-queries `aerospace list-workspaces --focused` on
  every workspace change (so the highlight reflects reality on multi-monitor
  setups).
- Replaced the calendar's "open Calendar.app" click with a world-clock popup.

## Nix-adaptations (vs. upstream)

- `sketchybarrc` (entry): shebang `#!/usr/bin/env lua` (was homebrew lua 5.4);
  removed the upstream from-source SBarLua installer (`git clone … make install`
  + `package.cpath`) — the HM wrapper provides sbarlua via `LUA_CPATH` and lua
  via `PATH`. Kept `sbar.event_loop()` (essential — without it no `:subscribe`
  callbacks or `sbar.exec` results fire).
- `init.lua`: removed the redundant trailing `SBAR.event_loop()` so the entry
  file's `end_config()`/`event_loop()` run and the config session closes
  (otherwise the bar loads with `drawing = off`).
- `default.lua`: `drawing = true` on `SBAR.bar()`; bar height is 38px with an opaque
  high-contrast background.
- `colors.lua`: `CONFIG_DIR` fallback (`os.getenv("CONFIG_DIR") or
  (os.getenv("HOME") .. "/.config/sketchybar")`).

## External dependencies

- **`Hack Nerd Font`** — used for icons. Installed via Nix (`nerd-fonts.hack` in
  `modules/darwin/packages.nix`, and `modules/nixos/desktop.nix`). The Homebrew
  `font-hack-nerd-font` cask was removed in favor of the Nix package.
- **`aerospace`** — on the wrapper's `PATH` via `programs.sketchybar.extraPackages`
  (in `modules/home/sketchybar.nix`), used by `items/spaces.lua` for the
  `aerospace workspace N` click action and `aerospace list-workspaces --focused`.

## Layout

```
sketchybarrc        entry point (executable, #!/usr/bin/env lua)
init.lua            requires globals + items (left: spaces, resources;
                    right: calendar, battery, VPN, volume)
globals.lua         SBAR / COLORS / DEFAULT_ITEM globals
colors.lua          high-contrast palette (hardcoded)
default.lua         default item styling + bar
items/spaces.lua    AeroSpace workspace indicator (aerospace_workspace_change)
items/resources.lua CPU + RAM usage
items/calendar.lua  local time/date + world-clock popup (Paris/London/UTC/NY/SF)
items/vpn.lua       VPN status indicator
items/*.lua         battery, volume
```