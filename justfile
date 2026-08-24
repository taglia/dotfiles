default:
    @just --list

build-darwin target="mbp":
    nix build ".#darwinConfigurations.{{target}}.system"

# nh handles the sudo escalation itself and prints a package diff first.
switch-darwin target="mbp":
    nh darwin switch . -H {{target}}

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

update-brew:
    brew update
    brew upgrade --formula
    brew upgrade --cask
    mas upgrade

# Review self-updating and unversioned casks monthly.
check-brew-greedy:
    brew outdated --cask --greedy --verbose

# Requiring at least one cask prevents a global greedy upgrade.
update-brew-greedy +casks:
    brew upgrade --cask --greedy {{casks}}

update-unstable:
    nix flake update nixpkgs-unstable

package:
    scripts/package.sh

push:
    git push origin main
    git push github main
