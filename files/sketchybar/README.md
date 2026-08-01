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
- Reworked `items/volume.lua` into a display-only item: it reads volume/mute
  from CoreAudio/AppleScript (built-in speakers, Bluetooth, …) and falls back
  to a neutral icon for HDMI/DisplayPort outputs (which expose no software
  volume to CoreAudio). All volume control — including the external monitor's
  DDC volume and the F10–F12 media keys — is delegated to **FineTune**
  (installed via the `finetune` cask in `modules/darwin/homebrew.nix`):
  left-click toggles FineTune's popup by synthesizing its global "Toggle
  FineTune Popup" hotkey (⌃⇧⌘-s, bound in FineTune's settings) —
  FineTune's menu bar popup only responds to raw mouse events
  (FluidMenuBarExtra `LocalEventMonitor`), so an accessibility (AXPress)
  click on its menu bar item does nothing, and the hotkey is the reliable
  path. Requires SketchyBar in System Settings → Privacy & Security →
  Accessibility (add the sketchybar binary via Cmd+Shift+G; the grant
  needs redoing when the nix store path of sketchybar changes). Also polls every 5s (`update_freq`) to follow
  default-output switches, which don't reliably fire `volume_change`.
  History: this item previously had a DDC backend using `m1ddc` on the
  wrapper's PATH plus a `/tmp` state file and a sketchybar-side safety net,
  paired with MonitorControl handling the media keys — all removed when
  FineTune (software volume-0 mute semantics, no hardware-mute VCP, so the
  C34J79x's garbage DDC readback can't wedge it) took over that job.
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
- **`FineTune`** — Homebrew cask (open source, GPL-3.0), not on the wrapper's
  PATH: `items/volume.lua` opens its menu-bar popup on click. Owns all
  volume/mute control including the monitor's DDC volume and the F10–F12
  media keys.

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