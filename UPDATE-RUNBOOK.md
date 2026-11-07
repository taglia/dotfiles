# Update runbook

Homebrew's prefix is owned by the separate admin user, and Homebrew keeps its
API catalog cache per user (`~/Library/Caches/Homebrew/api`). `brew update`
refreshes only the invoking user's copy and fails outright for the non-admin
daily user, so a `brew outdated` run as the daily user compares against a
stale catalog and reports phantom drift. Every `just *brew*` recipe therefore
refuses to run as anyone but the Homebrew admin, and runs `brew update` first.
`mas` is the opposite: it must run as the GUI-logged-in user.

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
   just update-mas           # as the GUI-logged-in user
   ```

   Casks with `auto_updates true` are covered here too. Homebrew reads the
   installed app bundle's `Info.plist` and upgrades such a cask only when the
   app on disk is older than the catalog version, so a stale, rarely-launched
   app (Acorn, BBEdit) appears in this list without `--greedy`, while an app
   that already updated itself is skipped instead of being reinstalled. The
   check needs a readable `.app`; pkg-only casks (`tailscale-app`,
   `sf-symbols`, `gpg-suite`, `1password-cli`) are never upgraded without
   `--greedy`.

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

1. Diagnostic: review Homebrew's record of self-updating casks.

   ```bash
   just check-brew-greedy    # as the admin user
   ```

   This is a diagnostic, not an upgrade queue, and most of its output needs
   no action. Why:

   - `--greedy` bypasses the bundle-version check used in the weekly step. It
     compares only Homebrew's own record of what it installed (the Caskroom
     folder name, which only Homebrew writes) with the catalog. Every app that
     updated itself since Homebrew last installed it is therefore listed with
     an older "installed" version even though the app on disk is current.
     That record drift is harmless; the weekly non-greedy upgrade already
     skips these apps on purpose. Upgrading one greedily only re-downloads the
     version that is already running, to make the record match.
   - Homebrew's "installed" version cannot be ahead of a fresh catalog. If the
     output shows installed AHEAD of the catalog, the catalog is stale, which
     means the recipe ran as the wrong user. It is not a sign that the app
     self-updated.
   - A genuinely stale app shows the same "installed != catalog" line as a
     self-updated one. To tell them apart, check the app's own version (About
     box, or `CFBundleShortVersionString` in its `Info.plist`) against the
     catalog version, not Homebrew's record.

   `tailscale-app` is filtered out of this output: it is self-update only
   (see step 2), Tailscale's own Sparkle updater is set to check and apply
   updates, and Homebrew's record of it can therefore never catch up.

   The output is only actionable for casks the weekly bundle check cannot
   cover: pkg-only casks with no `.app`, and casks that lack
   `auto_updates true` upstream although the app installs its own updates
   (`arduino-ide` via electron-updater and `mouseless@preview` via Sparkle, as
   of November 2026; the fix for those is an upstream cask change, after which
   they fall under the weekly step). Apps that only notify about updates and
   send you to a download page, such as balenaEtcher, are not in this class.

2. Upgrade only the selected casks that still need Homebrew to update them:

   ```bash
   just update-brew-greedy app-one app-two   # as the admin user
   ```

   `tailscale-app` is refused here by design: its pkg postinstall relaunches
   the app through LaunchServices in the invoking user's GUI session, which
   structurally fails from the admin's non-GUI shell (the install.log shows
   `procNotFound -600` at "Launching Tailscale..."), so brew reverts the
   upgrade. Update Tailscale from the app itself; the resulting drift in
   Homebrew's recorded version is harmless (routine non-greedy upgrades skip
   pkg-only casks entirely).

3. Confirm that installed Homebrew applications remain declared:

   ```bash
   just check-brew-declared
   ```

Do not use a global `--greedy` or `--force` cask upgrade.
