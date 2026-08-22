# Global configuration for Crush (charmbracelet/crush). Only the global
# ~/.config/crush/crush.json is managed here; Crush keeps model selection and
# session state in its data directory, so the Nix store symlink stays
# read-only. Project-level crush.json files still merge on top of this one.
#
# Note: current Crush has no theme option (styles are compiled in per
# provider), so only transparency is configured; revisit if upstream adds
# themes.
{ pkgs, ... }:

let
  json = pkgs.formats.json { };

  crushConfig = json.generate "crush.json" {
    "$schema" = "https://charm.land/crush.json";

    options.tui.transparent = true;
  };
in
{
  xdg.configFile."crush/crush.json".source = crushConfig;
}
