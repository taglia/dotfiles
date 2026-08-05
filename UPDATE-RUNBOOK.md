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

3. Preview, then apply routine Homebrew and App Store updates:

   ```bash
   just check-brew-updates
   just update-brew
   ```

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

2. Upgrade only the selected applications that still need Homebrew to update
   them:

   ```bash
   just update-brew-greedy app-one app-two
   ```

3. Confirm that installed Homebrew applications remain declared:

   ```bash
   just check-brew-declared
   ```

Do not use a global `--greedy` or `--force` cask upgrade.
