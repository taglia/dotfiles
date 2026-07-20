default:
    @just --list

build-darwin target="mbp":
    nix build ".#darwinConfigurations.{{target}}.system"

# nh handles the sudo escalation itself and prints a package diff first.
switch-darwin target="mbp":
    nh darwin switch . -H {{target}}

switch-utm-vm:
    sudo nixos-rebuild switch --flake .#utm-vm

switch-home target:
    nh home switch . -c {{target}}

# Mirrors .github/workflows/check.yml, except CI also runs an eval-only pass
# for all systems first (--no-build --all-systems).
check:
    nix flake check
    nix fmt -- --check
    find scripts files -name '*.sh' -type f -print0 | xargs -0 shellcheck
    nix shell nixpkgs#deadnix --command deadnix --fail .
    nix shell nixpkgs#statix --command statix check .
    nix shell nixpkgs#stylua --command stylua --check files/sketchybar
    nix shell nixpkgs#prettier --command prettier --check "files/**/*.ts"

gc *args:
    scripts/gc.sh {{args}}

check-brew-declared target="mbp":
    scripts/check-homebrew-apps.sh "{{target}}"

update-nix:
    nix flake update

check-brew-updates:
    brew update
    brew outdated --formula --verbose
    brew outdated --cask --greedy --verbose
    mas outdated

update-brew:
    brew update
    brew upgrade --formula
    brew upgrade --cask --greedy --force
    sudo mas upgrade

update:
    nix flake update
    just update-brew

update-unstable:
    nix flake update nixpkgs-unstable

package:
    scripts/package.sh

push:
    git push origin main
    git push github main
