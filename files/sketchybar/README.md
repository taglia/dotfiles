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
- **Right** (left → right on screen): frontmost-app icon
  (`items/front_app.lua`) — the focused app's icon, rendered natively by
  sketchybar via `app.<bundle-id>` (the name is resolved to a bundle id first,
  to avoid sketchybar's ambiguous running-apps name match); hover swaps it for
  a red `✕` pill signaling that click quits the app. VPN indicator
  (`items/vpn.lua`), battery (`items/battery.lua`), volume
  (`items/volume.lua`), and calendar (`items/calendar.lua`) — local time +
  date; click for a world-clock popup
  (Paris, London, UTC, New York, San Francisco, Sydney, Singapore, Tokyo)
  ordered chronologically with AM/PM and day offsets.

Colors come from `colors.lua`, which is **not in this tree**: it is generated
at build time from `lib/catppuccin.nix` (the repo's single source of truth for
the Catppuccin palette) and injected by `modules/home/sketchybar.nix`. The bar
uses an explicit high-contrast style: opaque near-black bar, white foreground,
bright yellow focused workspace.

## Local modifications (vs. upstream)

- Uses an explicit high-contrast palette (no theme switching, no
  `active_theme.txt`); `colors.lua` is generated from `lib/catppuccin.nix`.
- Removed Spotify, the theme picker, Borders, the menus widget, the control
  center, Pomodoro timers, the network part of resources, clipboard, separators/brackets, and the
  `icon_map`.
- Replaced the `rift`-based spaces widget with an AeroSpace event-driven
  workspace indicator that re-queries `aerospace list-workspaces --focused` on
  every workspace change (so the highlight reflects reality on multi-monitor
  setups).
- Replaced the calendar's "open Calendar.app" click with a world-clock popup.
- Reworked `items/volume.lua` into a dual-backend item: CoreAudio/AppleScript
  for normal outputs, DDC/CI via `m1ddc` (with a state file, since the
  monitor can't be read back) when the default output is an HDMI/DisplayPort
  monitor. Also polls every 5s (`update_freq`) to follow default-output
  switches, which don't reliably fire `volume_change`.
- Added a frontmost-app icon (`items/front_app.lua`), leftmost on the right
  side: native `app.<bundle-id>` icon rendering (name → bundle id via
  `id of app`, to dodge sketchybar's ambiguous name loop), hover shows a red
  `✕` close affordance, click quits the app (with a no-quit denylist for
  Finder/Dock/etc.).

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

## External dependencies

- **`Hack Nerd Font`** — used for icons. Installed via Nix (`nerd-fonts.hack` in
  `modules/darwin/packages.nix`, and `modules/nixos/desktop.nix`). The Homebrew
  `font-hack-nerd-font` cask was removed in favor of the Nix package.
- **`aerospace`** — on the wrapper's `PATH` via `programs.sketchybar.extraPackages`
  (in `modules/home/sketchybar.nix`), used by `items/spaces.lua` for the
  `aerospace workspace N` click action and `aerospace list-workspaces --focused`.
- **`m1ddc`** — also on the wrapper's `PATH` via `extraPackages`, used by
  `items/volume.lua` when the default audio output is an HDMI/DisplayPort
  monitor (macOS exposes no software volume for those; AppleScript returns
  "missing value", which is the detection signal). Click toggles mute over
  DDC/CI. Since the Samsung C34J79x returns garbage on DDC reads, the item
  tracks last-known volume/mute in `/tmp/sketchybar-ddc-volume-$USER`.
  "Mute" is volume 0 (restore on unmute), NOT the hardware-mute VCP command:
  the C34J79x stays hardware-muted until an explicit mute-off arrives, which
  a keyboard/MonitorControl volume change never sends — so hardware mute set
  from the bar could only be cleared from the bar. With volume-0 semantics
  any volume change from any source restores sound; unmute also sends
  `mute off` first in case the hardware mute was set elsewhere. Volume
  changes made by MonitorControl via the keyboard bypass CoreAudio and
  cannot be observed by the bar (icon may briefly show a stale state).

## Layout

```
sketchybarrc        entry point (executable, #!/usr/bin/env lua)
init.lua            requires globals + items (left: spaces, resources;
                    right, left→right: front_app, VPN, battery, volume,
                    calendar)
globals.lua         SBAR / COLORS / DEFAULT_ITEM globals
default.lua         default item styling + bar
helpers/            shell/python helpers: the VPN status probe
                    (vpn-status.sh + tailscale-exit-node.py) and the
                    next-DST-transition probe (next-dst-change.sh)
items/spaces.lua    AeroSpace workspace indicator (aerospace_workspace_change)
items/resources.lua CPU + RAM usage
items/calendar.lua  local time/date + world-clock popup (8 zones;
                    DST probe: helpers/next-dst-change.sh)
items/vpn.lua       VPN status indicator (probe: helpers/vpn-status.sh)
items/front_app.lua frontmost-app icon (hover = red ✕ close affordance, click = quit)
items/*.lua         battery, volume
```