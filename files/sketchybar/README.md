# SketchyBar config

This directory is the SketchyBar status bar configuration. It is intentionally
kept as a self-contained tree, separate from the rest of the dotfiles, so it is
easily identifiable as "the SketchyBar config" and not mixed with hand-written
Nix code or other app configs.

The only Nix-side references to it are:
- `modules/home/sketchybar.nix` — the Home Manager module that installs this
  whole directory verbatim into `~/.config/sketchybar/` via
  `programs.sketchybar.config.source` (recursive), wires the launchd agent, and
  puts `aerospace` and the private network-status helper on the wrapper's
  `PATH` (`extraPackages`). Its `modules/home/sketchybar/wifi-unredactor.nix`
  package expression builds the Wi-Fi permission helper; see **Network indicator** below.
- one line in `flake.nix` (`hosts.mbp.modules`) that imports that module.
- `modules/darwin/aerospace.nix` — `exec-on-workspace-change` triggers the
  `aerospace_workspace_change` sketchybar event consumed by `items/spaces.lua`,
  using the absolute nix store path to `sketchybar` (aerospace's launchd daemon
  does not see the Home Manager user PATH).

Everything SketchyBar-related lives here, in those two modules, or in the
private `modules/home/sketchybar/` packaging directory.

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
  (`items/vpn.lua`), network (`items/network.lua`), battery (`items/battery.lua`), volume
  (`items/volume.lua`), and calendar (`items/calendar.lua`) — local time +
  date; click for a world-clock popup
  (Paris, London, UTC, New York, San Francisco, Sydney, Singapore, Tokyo)
  ordered chronologically with AM/PM and day offsets.

Colors come from `colors.lua`, which is **not in this tree**: it is generated
at build time from `lib/catppuccin.nix` (the repo's single source of truth for
the Catppuccin palette) and injected by `modules/home/sketchybar.nix`. The bar
uses an explicit high-contrast style: opaque near-black bar, white foreground,
bright yellow focused workspace.

## Network indicator

`items/network.lua` sits between VPN and battery. The top row contains Wi-Fi and
wired-link icons, independently crossed out when disconnected. The bottom row
shows the SSID (first 10 Unicode code points plus `…` for longer names). Hover
over either row for the full SSID and wired-link state; click either row to open
macOS Network Settings. Both connections can be active at once. A wired link
means an active physical Ethernet/Thunderbolt interface, **not** proof of Internet
access or which route is preferred; VPNs and virtual bridges are excluded.
Updates run on `wifi_change`, wake, and every 30 seconds (including wired changes).

### Why a separate app?

Recent macOS versions redact SSIDs from command-line tools unless the calling
app has Location Services authorization. The private Nix derivation
`modules/home/sketchybar/wifi-unredactor.nix` builds the Swift
[wifi-unredactor](https://github.com/noperator/wifi-unredactor) app from pinned
revision `c4acc3e1f8093c6a365195f1240546b342aa0f56`, with a fixed source hash.
It uses CoreWLAN and CoreLocation. There is no Homebrew dependency, global CLI
installation, background daemon, or continuous location tracking.

Everything is wired solely through `modules/home/sketchybar.nix`:

- The app is built into the **Nix store**. Home Manager exposes it at
  `~/Applications/SketchyBar/wifi-unredactor.app` for permission setup; this is a
  symlink to the store bundle, not an unmanaged copy.
- `sketchybar-network-status` is on **SketchyBar's private PATH**, not the global
  user PATH. It runs `helpers/network-status.sh`, using the app's absolute store path
  and Nix-provided `jq`. Standard macOS tools detect physical links.
- Upstream's source is **unmodified**. Each probe calls the executable without
  arguments; upstream handles authorization, prints JSON, and exits. It calls
  `requestAlwaysAuthorization()` on every launch, so a refresh may prompt if
  permission has not been determined (for example, after an update). There is
  no custom status mode or timeout. The widget does not start overlapping probes
  while one is pending.

### One-time setup (after applying the Home Manager configuration)

```sh
open "$HOME/Applications/SketchyBar/wifi-unredactor.app"
```

Allow Location Services, then check **System Settings → Privacy & Security →
Location Services → wifi-unredactor** is enabled. Upstream notes that the initial
prompt may add the entry without enabling its switch. No root or Full Disk
Access is needed. The bar picks up the SSID on its next refresh.

Without authorization, a detected Wi-Fi link still shows a connected icon and
`Unknown` below; its hover text explains that the SSID is unavailable. It is not
misrepresented as disconnected. To diagnose directly:

```sh
"$HOME/Applications/SketchyBar/wifi-unredactor.app/Contents/MacOS/wifi-unredactor"
```

Unchanged derivation inputs keep the same store path. Updating the source,
build recipe, compiler, SDK, or dependencies can change it—even if the app's own
source stays pinned. **macOS permission persistence across such changes is not
guaranteed**: you may need to reopen the app and re-enable Location Services;
stale permission entries may remain. The stable Home Manager symlink does not
guarantee a stable privacy identity. Permission grants are deliberately manual,
not scripted by Nix.

### Security review of the pinned source

All five upstream files at the pinned revision were reviewed: the Swift source,
`Info.plist`, build/install script, README, and `.gitignore`. No network requests,
telemetry, shell execution, persistence/LaunchAgents, credential access, or
arbitrary file access were found in the app. It requests Location Services
authorization, reads the Wi-Fi interface name/SSID/BSSID, prints JSON to stdout,
and exits. It does not start location updates. The status wrapper consumes only
the SSID; nothing is sent to a remote service or written to a status cache.

The upstream installer compiles with `swiftc` and replaces its app under
`~/Applications`; **we do not execute that installer**. Nix compiles the reviewed
source unchanged and ad-hoc signs the app bundle. This is not Developer ID
signing/notarization. The built binary's linked libraries were inspected and are
Apple system frameworks/Swift runtimes.
The upstream snapshot includes no explicit license; this is a private local
package, not a proposal to redistribute it through nixpkgs.

The source pin and hash prevent silently accepting different upstream content;
they are not a proof of safety. This was a source review, not a formal audit, and
does not cover the entire compiler/SDK supply chain. Re-review source changes
before updating the pin. Location Services is a sensitive permission even though
this source uses it only to read Wi-Fi information.

Regression checks (repository root): `lua scripts/check-sketchybar-network.lua`
with Lua 5.3+ (the SketchyBar wrapper provides a compatible Lua), and
`bash scripts/check-sketchybar-network.sh` with `jq` on PATH.

## Time Machine

The Time Machine icon is visible only during a backup or when the last known
successful backup is older than seven days. It is green while active and orange
when overdue; idle with recent or unavailable history stays hidden.
Hover shows the current phase (or an overdue warning while idle); only copying with valid progress shows a
percentage. Click for status, the last successful backup's relative age, and a
bullet list of the five newest available backup dates/times (local timezone).
During copying, data copied / total (decimal B–PB) and estimated time remaining
appear when reported by Time Machine. No destination row is displayed.
An orange popup warning appears when that backup is older than seven days.

History uses the five newest destination `SnapshotDates` entries in macOS's local
`com.apple.TimeMachine` preferences, not local snapshots or attempted backups.
This is last-known history, available without mounting the destination or
requesting root/Full Disk Access; it cannot detect backups deleted remotely.
A native `defaults`/`plutil`/`date` helper reads history without JavaScript/AppleScript.
`defaults export` accesses the system preferences domain through CFPreferences;
direct plist access is denied to SketchyBar by macOS privacy controls even when
Terminal can read the file. No additional Full Disk Access grant is needed.
Failures are logged; transient failures preserve previously read dates and show
a refresh-failed notice. Missing history is unavailable, not "never backed up".
With multiple destinations, the newest five backups across them are used.
Status and history are refreshed every 30 seconds, even while the
icon is hidden, and on wake or opening the popup. The preference schema is
macOS-internal and may change.

Regression checks: `bash scripts/check-timemachine.sh`,
`bash scripts/check-timemachine-history.sh` (macOS), and
`lua scripts/check-timemachine.lua` (from the repository root).

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
                    right, left→right: front_app, VPN, network, battery, volume,
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
items/network.lua   stacked Wi-Fi + wired icons / SSID (helpers/network-status.sh)
items/front_app.lua frontmost-app icon (hover = red ✕ close affordance, click = quit)
items/*.lua         battery, volume
```