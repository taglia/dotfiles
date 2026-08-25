# Update runbook

## Weekly

1. Update, review and verify the locked inputs:

   ```bash
   just update-nix
   git diff -- flake.lock
   just check
   ```

2. Activate the verified configuration. This also activates the pinned
   Homebrew client and Rootshell tap:

   ```bash
   just switch-darwin
   ```

3. Preview, then apply routine Homebrew and App Store updates. Homebrew runs
   as the admin user (owner of the prefix); mas must run as the GUI-logged-in
   user instead, because it drives the App Store daemons of the invoking
   user's login session and hangs forever without one:

   ```bash
   just check-brew-updates   # as the admin user
   just update-brew          # as the admin user
   just update-brew-blocked  # as the admin user
   just update-mas           # as the GUI-logged-in user
   ```

   `update-brew-blocked` covers the casks whose vendor background updater is
   deliberately not allowed to run (the `updater_blocked` list in the
   justfile, e.g. Google Chrome without its Keystone agent) — for those,
   Homebrew greedy upgrades are the only update channel, and browsers should
   not wait for the monthly review. The underlying script skips any cask
   whose installed version is ahead of the catalog, where a greedy upgrade
   would downgrade.

   Repeat this step once midweek if you want application updates more often;
   the flake does not need another update.

4. Update `nixpkgs-unstable` between weekly runs only when required:

   ```bash
   just update-unstable
   just check
   just switch-darwin
   ```

Accept trusted in-app security updates promptly. Routine feature updates can
wait for the next weekly run.

## Monthly

1. Review casks that self-update or do not expose a comparable version:

   ```bash
   just check-brew-greedy
   ```

   This is a stale-app hunt, not an upgrade queue. For each listed cask,
   compare the direction of the version drift:

   - Installed version AHEAD of the cask catalog: the app self-updated and
     Homebrew's catalog is lagging. Do nothing — a greedy upgrade here
     would install the older catalog version, i.e. a downgrade.
   - Installed version BEHIND: the app is genuinely stale. This mostly
     happens to rarely-launched apps, because in-app updaters only run
     while the app runs — so the first fix is simply opening the app and
     letting it update itself. Use step 2 only for apps whose installers
     work headless.

2. Upgrade only the selected applications that still need Homebrew to update
   them:

   ```bash
   just update-brew-greedy app-one app-two
   ```

   `tailscale-app` is refused here by design: its pkg postinstall relaunches
   the app through LaunchServices in the invoking user's GUI session, which
   structurally fails from the admin's non-GUI shell (the install.log shows
   `procNotFound -600` at "Launching Tailscale..."), so brew reverts the
   upgrade. Update Tailscale from the app itself; the resulting drift in
   Homebrew's recorded version is harmless (routine non-greedy upgrades skip
   auto-updating casks entirely).

3. Confirm that installed Homebrew applications remain declared:

   ```bash
   just check-brew-declared
   ```

Do not use a global `--greedy` or `--force` cask upgrade.
