default:
    @just --list

build-darwin target="mbp":
    nix build ".#darwinConfigurations.{{target}}.system"

# nh handles the sudo escalation itself and prints a package diff first.
# The agenix kickstart re-asserts the decrypted-secret symlinks (~/.ssh/config,
# ~/.config/aerc/accounts.conf, ~/.local/share/agenix/*): the launchd agent
# otherwise only re-runs at login or when the secret set changes, so a
# hand-deleted symlink would survive a plain switch. The agent lives in the
# console (GUI) user's domain, not the invoker's — switches normally run from
# the admin account — so kickstart it there: directly when invoker == console
# user, else as root via nh's still-cached sudo timestamp (-n: never prompt).
# Silently a no-op when neither works (SSH session, nobody at the console).
switch-darwin target="mbp":
    nh darwin switch . -H {{target}}
    uid="$(id -u "$(stat -f%Su /dev/console)")"; svc="gui/$uid/org.nix-community.home.activate-agenix"; launchctl kickstart -k "$svc" 2>/dev/null || sudo -n launchctl kickstart -k "$svc" 2>/dev/null || true

# The NixOS targets are on-box switches: run them from a clone of this repo on
# the VM / instance itself.
switch-utm-vm:
    sudo nixos-rebuild switch --flake .#utm-vm

switch-ec2-x86-vm:
    sudo nixos-rebuild switch --flake .#ec2-x86-vm

switch-home target:
    nh home switch . -c {{target}}

# Mirrors .github/workflows/check.yml, except CI also evaluates non-native systems.
# Run cheap checks before the native Nix build, matching CI.
check:
    nix fmt -- --check
    nix shell --inputs-from . nixpkgs#shellcheck --command bash scripts/check-lint.sh shellcheck
    nix shell --inputs-from . nixpkgs#deadnix --command bash scripts/check-lint.sh deadnix
    nix shell --inputs-from . nixpkgs-unstable#statix --command bash scripts/check-lint.sh statix
    nix shell --inputs-from . nixpkgs#stylua --command bash scripts/check-lint.sh stylua
    nix shell --inputs-from . nixpkgs#prettier --command bash scripts/check-lint.sh prettier
    nix shell --inputs-from . nixpkgs#python3 --command python3 -B -m unittest discover -s files/log-maintenance -v
    nix shell --inputs-from . nixpkgs#python3 --command python3 -B -m unittest discover -s files/littlesnitch-status -v
    nix shell --inputs-from . nixpkgs#lua --command lua scripts/check-sketchybar-littlesnitch.lua
    nix shell --inputs-from . nixpkgs-unstable#nodejs nixpkgs#typescript --command bash scripts/check-agent-async.sh
    nix flake check

gc *args:
    scripts/gc.sh {{args}}

check-brew-declared target="mbp":
    scripts/check-homebrew-apps.sh "{{target}}"

update-nix:
    nix flake update

# Homebrew's prefix is owned by the admin user and the API catalog cache is per
# user (~/Library/Caches/Homebrew/api): `brew update` refreshes only the invoking
# user's copy and fails outright for the non-admin daily user. A `brew outdated`
# run as anyone else compares against that user's stale catalog and reports
# phantom drift, so every brew recipe insists on the prefix owner.
brew_admin_guard := '[ "$(stat -f%Su "$(brew --prefix)")" = "$(id -un)" ] || { echo "error: run as the Homebrew admin ($(stat -f%Su "$(brew --prefix)")), not $(id -un)" >&2; exit 1; }'

# Run as the Homebrew admin user, which owns the prefix.
check-brew-updates:
    {{brew_admin_guard}}
    brew update
    brew outdated --formula --verbose
    brew outdated --cask --verbose
    mas outdated

# Run as the Homebrew admin user, which owns the prefix. Casks with
# `auto_updates true` are upgraded only when the installed app bundle is older
# than the catalog; apps that already updated themselves are skipped.
update-brew:
    {{brew_admin_guard}}
    brew update
    brew upgrade --formula
    brew upgrade --cask

# mas only asks the App Store daemons of the invoking user's login session to
# install, so under `su - <admin>` (no Aqua session, no signed-in App Store
# account) it waits forever for completion events that cannot arrive; the
# guard fails fast instead of hanging.
# Run as the GUI-logged-in user, NOT the Homebrew admin.
update-mas:
    [ "$(stat -f%Su /dev/console)" = "$(id -un)" ] || { echo "error: run mas as the console (GUI) user, not $(id -un)" >&2; exit 1; }
    mas upgrade

# Casks brew must never upgrade: their pkg postinstall relaunches the app via
# LaunchServices in the invoking user's GUI session, which structurally fails
# from the admin's non-GUI shell (LaunchServices procNotFound -600;
# tailscale-app confirmed via install.log). They update themselves in-app, so
# Homebrew's record of them never catches up; they are hidden from the greedy
# diagnostic below and refused by update-brew-greedy.
self_update_only := "tailscale-app"

# Diagnostic only, not an upgrade queue. `--greedy` bypasses the bundle-version
# check, so this lists every auto_updates cask whose Caskroom record differs
# from the catalog, including apps that already self-updated (harmless record
# drift). The actionable list is the plain `brew outdated --cask` in
# check-brew-updates. Installed AHEAD of the catalog means a stale catalog, not
# a self-update; `brew update` runs first so that cannot happen as the admin.
# See UPDATE-RUNBOOK.md.
check-brew-greedy:
    {{brew_admin_guard}}
    brew update
    brew outdated --cask --greedy --verbose | { grep -v -E "^($(printf '%s' "{{self_update_only}}" | tr ' ' '|')) " || true; }

# Requiring at least one cask prevents a global greedy upgrade.
update-brew-greedy +casks:
    {{brew_admin_guard}}
    for c in {{casks}}; do case " {{self_update_only}} " in *" $c "*) echo "error: $c is self-update only; update it from the app itself (see UPDATE-RUNBOOK.md)" >&2; exit 1;; esac; done
    brew upgrade --cask --greedy {{casks}}

update-unstable:
    nix flake update nixpkgs-unstable

package:
    scripts/package.sh

push:
    git push origin main
    git push github main
