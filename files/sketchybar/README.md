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
- **Left** (left → right): AeroSpace workspaces (`items/spaces.lua`), network
  (`items/network.lua`), upload/download bandwidth (`items/bandwidth.lua`),
  VPN (`items/vpn.lua`). Workspaces 1–9 highlight the focused workspace;
  no macOS Spaces or `rift`. Clicking bandwidth opens Little Snitch Network Monitor.
- **Right** (left → right): backup indicators when visible (CCC, Time Machine),
  frontmost app (`items/front_app.lua`), CPU → RAM → disk (`items/resources.lua`),
  battery (`items/battery.lua`), volume (`items/volume.lua`), and calendar
  (`items/calendar.lua`). The front-app icon uses `app.<bundle-id>` to avoid
  ambiguous app-name matches; hover describes the quit action in a popup.
  The calendar shows local time + date; hover for a world-clock popup
  (Paris, London, UTC, New York, San Francisco, Sydney, Singapore, Tokyo)
  ordered chronologically with AM/PM and day offsets.

Colors come from `colors.lua`, which is **not in this tree**: it is generated
at build time from `lib/catppuccin.nix` (the repo's single source of truth for
the Catppuccin palette) and injected by `modules/home/sketchybar.nix`. The bar
uses an explicit high-contrast style: opaque near-black bar, white foreground,
bright yellow focused workspace.

`init.lua` controls the module order: left-side modules are loaded left-to-right,
right-side modules right-to-left. The resources module creates disk, RAM, then
CPU to produce CPU → RAM → disk on screen. Bandwidth is a separate module so it
can stay on the left; each group has its own background bracket.
Layout/bandwidth regression check: `lua scripts/check-sketchybar-layout.lua`.

## Hover popups and click actions

Hover over a workspace, CPU, memory, network, VPN, either calendar row, the
front-app icon, or a visible backup indicator to open its details popup. Hover information never
expands an in-bar label or replaces an icon. Every popup closes immediately when
the pointer leaves its bar item, including moving down toward the popup itself.
Only one hover popup is open at once.
CPU/memory process lists refresh while visible, and their extra refresh ticker
stops when closed. CCC progress and Time Machine status/history refresh in place
inside their popups; finishing a backup also closes a popup if its icon is hidden.

- **Workspace click:** switches to that AeroSpace workspace, as before.
- **CPU / memory click:** opens Activity Monitor.
- **Disk click:** opens Disk Utility.
- **VPN click:** opens the Tailscale GUI app (not its CLI).
- **Calendar:** hover for the world-clock popup; click either time or date to
  open The Clock.
- **Front app click:** quits the focused app, retaining the system-app denylist;
  its popup names the app and says whether quitting is available.
- **Time Machine click:** still toggles its status/history popup as an alternative
  to hovering. CCC shows progress in a popup while its task is running.

`utils.hover_popup()` subscribes to `mouse.entered` and `mouse.exited` only.
It deliberately does **not** subscribe to `mouse.exited.global`, which would
make SketchyBar suppress item-exit events when crossing into a popup
([upstream explanation](https://github.com/FelixKratz/SketchyBar/issues/178#issuecomment-1153011527)).
There is no close delay, timer, or pointer polling.

Regression check: `lua scripts/check-sketchybar-popups.lua` (Lua 5.3+) from the
repository root. Probes and app launches are mocked; nothing is opened.

## Workspace popups

Each workspace (1–9) shows the names of apps with windows on that workspace,
alphabetically sorted (case-insensitive) and deduplicated when an app has multiple
windows. The popup refreshes on each hover, using:

```sh
aerospace list-windows --workspace 1 --format '%{app-name}' --json
```

Only app names are requested—not window titles. JSON preserves names containing
spaces or punctuation. Empty workspaces show `No windows`; failed/malformed
queries show `Window list unavailable`. Queries are asynchronous, and late replies
after exiting/reopening a popup are ignored. No workspace-window polling runs
while the popups are closed. Clicking still switches workspace; hover never does.

Regression check: `lua scripts/check-sketchybar-spaces.lua` (Lua 5.3+), using
mocked AeroSpace responses without changing workspaces or opening applications.

## Network indicator

`items/network.lua` sits between workspaces and bandwidth on the left. The top row contains Wi-Fi and
wired-link icons, independently crossed out when disconnected. The bottom row
shows the SSID (first 10 Unicode code points plus `…` for longer names). Hover
over either row for a three-row popup; click either row to open macOS Network Settings.
The popup shows the full SSID on the Wi-Fi row and adapter-reported link speed on
the wired row, each followed by its local IPv4 address and gateway in brackets:

```text
Wi-Fi: Full SSID — 192.168.1.20 [192.168.1.1]
Wired: 2.5 Gbps — 192.168.2.20 [192.168.2.1]
Public IP: 203.0.113.7
```

Disconnected links say `Disconnected`. Active links without IPv4 say `No IP`;
missing gateways or link speeds say `Gateway unavailable` or `Speed unavailable`.
The Wi-Fi/wired addresses come from each interface's first IPv4 address, not IPv6
or the public-IP service. Gateway lookup is interface-scoped and rejects a result naming another
interface, so it does not accidentally display the VPN/default interface's gateway.
Wired speed comes from `ifconfig` media (preferring the negotiated medium when
reported); it is a link rate in Mbps/Gbps, not measured throughput. Multiple active
wired adapters share the wired row, with their interface names and individual
speed/address/gateway details separated by semicolons. Both connections can be active at once. A wired link
means an active physical Ethernet/Thunderbolt interface, **not** proof of Internet
access or which route is preferred; VPNs and virtual bridges are excluded.
Updates run on `wifi_change`, wake, and every 30 seconds (including wired changes).

### Public IP lookup

The third row queries [ipify](https://www.ipify.org/) at `https://api.ipify.org`
for the public **IPv4** address. It reflects the route used to reach that service:
a full-tunnel VPN normally shows its exit IP, while split-tunnel routing may differ.
This is not a separate public address for each physical interface.

Lookups run asynchronously only while the popup is open: on hover, then on local
refresh ticks when the 60-second in-memory cache expires. Failures use the same
cooldown. Wi-Fi-change/wake events invalidate the cache, with the next lookup
on hover if the popup is hidden. Other routing/VPN changes are picked up on the
next uncached lookup. Requests cannot overlap; results from a request spanning
a Wi-Fi-change/wake event are discarded. The row shows `Checking…` while fetching
and `Unavailable` for errors or invalid responses, rather than retaining a stale IP.

The macOS `curl` uses HTTPS, a 3-second connection timeout, a 5-second total timeout,
and a 64-byte response limit. User curl configuration and HTTP proxy environment
settings are bypassed so the request follows the machine's routing. No credentials,
SSID, or local addresses are sent; ipify necessarily sees the request's public
source IP. Nothing is persisted to disk. This lookup is independent of the local
status helper and does not alter wifi-unredactor or Location Services permissions.
Regression tests mock all HTTP responses; they do not contact ipify.

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
Hover opens a popup with the current phase (a percentage only while copying with
valid progress), an overdue warning when applicable, the last successful backup's
relative age, and the five newest available backup dates/times (local timezone).
Click still toggles that same popup; no progress label expands in the bar.
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
- Replaced the calendar's "open Calendar.app" click with The Clock; the
  world-clock popup opens on hover.
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
  `id of app`, to dodge sketchybar's ambiguous name loop), hover shows the app
  name and quit action in a popup, click quits the app (with a no-quit denylist for
  Finder/Dock/etc.).

## Nix-adaptations (vs. upstream)

- SketchyBar and AeroSpace use the pinned `nixpkgs-unstable` input without
  changing the default stable package set. The AeroSpace app, its CLI on
  SketchyBar's wrapper `PATH`, and the SketchyBar workspace-change trigger
  use matching packages in `modules/darwin/aerospace.nix` and
  `modules/home/sketchybar.nix`; AeroSpace 0.21 changed its client/server protocol.
  AeroSpace's `focus-follows-mouse.enabled` is enabled, retaining the existing
  lazy pointer movement on keyboard-driven focus changes. This is window
  focus-following, not a guarantee that hovering the bar focuses its monitor.
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

- **The Clock** — Mac App Store app (`488764545`), declared in
  `modules/darwin/homebrew.nix`. Both calendar rows open the GUI using its
  bundle ID `com.fabriceleyne.theclock`.
- **`Hack Nerd Font`** — used for icons. Installed via Nix (`nerd-fonts.hack` in
  `modules/darwin/packages.nix`, and `modules/nixos/desktop.nix`). The Homebrew
  `font-hack-nerd-font` cask was removed in favor of the Nix package.
- **`aerospace`** — on the wrapper's `PATH` via `programs.sketchybar.extraPackages`
  (in `modules/home/sketchybar.nix`), used by `items/spaces.lua` for the
  `aerospace workspace N` click action, `aerospace list-workspaces --focused`,
  and workspace-scoped `aerospace list-windows` hover queries.
- **`FineTune`** — Homebrew cask (open source, GPL-3.0), not on the wrapper's
  PATH: `items/volume.lua` opens its menu-bar popup on click. Owns all
  volume/mute control including the monitor's DDC volume and the F10–F12
  media keys.

## Layout

```
sketchybarrc        entry point (executable, #!/usr/bin/env lua)
init.lua            left→right: spaces, network, bandwidth, VPN;
                    right, left→right: CCC/Time Machine (when visible), front_app,
                    CPU, RAM, disk, battery, volume, calendar
globals.lua         SBAR / COLORS / DEFAULT_ITEM globals
default.lua         default item styling + bar
helpers/            shell/python helpers: the VPN status probe
                    (vpn-status.sh + tailscale-exit-node.py) and the
                    next-DST-transition probe (next-dst-change.sh)
items/spaces.lua    AeroSpace workspaces + deduplicated app-name hover popups
items/resources.lua right-side CPU + RAM + disk usage group
items/bandwidth.lua left-side upload/download rates (click = Little Snitch)
items/calendar.lua  local time/date + world-clock popup (8 zones;
                    DST probe: helpers/next-dst-change.sh)
items/vpn.lua       VPN status indicator (probe: helpers/vpn-status.sh)
items/network.lua   stacked Wi-Fi + wired icons / SSID (helpers/network-status.sh)
items/front_app.lua frontmost-app icon (hover = app/quit popup, click = quit)
items/*.lua         battery, volume
```