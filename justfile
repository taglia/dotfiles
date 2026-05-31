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

update:
    nix flake update

update-unstable:
    scripts/update-pkgs-unstable.sh

package:
    scripts/package.sh
