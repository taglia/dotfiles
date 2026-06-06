default:
    @just --list

build-darwin target="mbp":
    nix build ".#darwinConfigurations.{{target}}.system"

switch-darwin target="mbp":
    sudo darwin-rebuild switch --flake ".#{{target}}"

switch-home target:
    nix run github:nix-community/home-manager/release-26.05 -- switch --flake ".#{{target}}"

check:
    nix flake check
    bash -n scripts/*.sh
    shellcheck scripts/*.sh

gc *args:
    scripts/gc.sh {{args}}

brew-check target="mbp":
    scripts/check-homebrew-apps.sh "{{target}}"

update-all:
    nix flake update

check-brew-and-mas-updates:
    brew update
    brew outdated --formula --verbose
    brew outdated --cask --greedy --verbose
    mas outdated

update-brew-and-mas:
    brew update
    brew upgrade --formula
    brew upgrade --cask --greedy --force
    sudo mas upgrade

update-everything:
    nix flake update
    just update-brew-and-mas

update-unstable:
    scripts/update-pkgs-unstable.sh

package:
    scripts/package.sh

push:
    git push origin main
    git push github main
