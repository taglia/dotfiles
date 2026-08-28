default:
    @just --list

build-darwin target="mbp":
    nix build ".#darwinConfigurations.{{target}}.system"

# nh handles the sudo escalation itself and prints a package diff first.
# The agenix kickstart re-asserts the decrypted-secret symlinks (~/.ssh/config,
# ~/.config/aerc/accounts.conf, ~/.local/share/agenix/*): the launchd agent
# otherwise only re-runs at login or when the secret set changes, so a
# hand-deleted symlink would survive a plain switch. `|| true` because the
# gui/ domain (and the agent itself) may be absent, e.g. over SSH.
switch-darwin target="mbp":
    nh darwin switch . -H {{target}}
    launchctl kickstart -k "gui/$(id -u)/org.nix-community.home.activate-agenix" || true

# The NixOS targets are on-box switches: run them from a clone of this repo on
# the VM / instance itself.
switch-utm-vm:
    sudo nixos-rebuild switch --flake .#utm-vm

switch-ec2-x86-vm:
    sudo nixos-rebuild switch --flake .#ec2-x86-vm

switch-home target:
    nh home switch . -c {{target}}

# Mirrors .github/workflows/check.yml, except CI also runs an eval-only pass
# for all systems first (--no-build --all-systems).
check:
    nix flake check
    nix fmt -- --check
    find scripts files -name '*.sh' -type f -print0 | xargs -0 nix shell --inputs-from . nixpkgs#shellcheck --command shellcheck
    nix shell --inputs-from . nixpkgs#deadnix --command deadnix --fail .
    nix shell --inputs-from . nixpkgs#statix --command statix check .
    nix shell --inputs-from . nixpkgs#stylua --command stylua --check files/sketchybar
    nix shell --inputs-from . nixpkgs#prettier --command prettier --check "files/**/*.ts"

gc *args:
    scripts/gc.sh {{args}}

check-brew-declared target="mbp":
    scripts/check-homebrew-apps.sh "{{target}}"

update-nix:
    nix flake update

check-brew-updates:
    brew update
    brew outdated --formula --verbose
    brew outdated --cask --verbose
    mas outdated

# Run as the Homebrew admin user, which owns the prefix.
update-brew:
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

# Review self-updating and unversioned casks monthly. Read the output
# directionally: installed AHEAD of the catalog means the app self-updated
# and Homebrew is lagging (do nothing — a greedy upgrade would downgrade);
# installed BEHIND means the app is stale (see UPDATE-RUNBOOK.md).
check-brew-greedy:
    brew outdated --cask --greedy --verbose

# Casks brew must never upgrade: their pkg postinstall relaunches the app via
# LaunchServices in the invoking user's GUI session, which structurally fails
# from the admin's non-GUI shell (LaunchServices procNotFound -600;
# tailscale-app confirmed via install.log). Update these in-app instead.
self_update_only := "tailscale-app"

# Requiring at least one cask prevents a global greedy upgrade.
update-brew-greedy +casks:
    for c in {{casks}}; do case " {{self_update_only}} " in *" $c "*) echo "error: $c is self-update only; update it from the app itself (see UPDATE-RUNBOOK.md)" >&2; exit 1;; esac; done
    brew upgrade --cask --greedy {{casks}}

update-unstable:
    nix flake update nixpkgs-unstable

package:
    scripts/package.sh

push:
    git push origin main
    git push github main
