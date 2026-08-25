# Declarative Homebrew tap-trust for interactive shells: with
# XDG_CONFIG_HOME set (shells.nix), brew reads trust from
# $XDG_CONFIG_HOME/homebrew/trust.json instead of the ~/.homebrew file that
# nix-homebrew's activation writes — see lib/homebrew-trust.nix for the
# split-brain details and the shared entry list. Imported only by the Darwin
# home targets. `brew trust`/`brew untrust` cannot edit the store-backed
# symlink; change lib/homebrew-trust.nix and switch instead.
{ pkgs, ... }:

let
  json = pkgs.formats.json { };
  trust = import ../../lib/homebrew-trust.nix;
in
{
  xdg.configFile."homebrew/trust.json" = {
    source = json.generate "homebrew-trust.json" {
      trustedcasks = trust.casks;
    };
    # Replace a pre-existing hand-written trust.json instead of aborting
    # activation on the collision.
    force = true;
  };
}
