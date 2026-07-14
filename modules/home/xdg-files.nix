{
  config,
  pkgs,
  lib,
  ...
}:

let
  # Single source of truth for the static config files we link into XDG config.
  # Keys are paths relative to xdg.configHome; values are the repo sources.
  # Both the `xdg.configFile` entries and the pre-link cleanup step below are
  # derived from this set so the two can never drift apart.
  managedXdgConfig = {
    "btop/btop.conf" = ../../files/btop/btop.conf;
    "ghostty/config" = ../../files/ghostty/config;
    "ghostty/shaders" = ../../files/ghostty/shaders;
    "glow/glow.yml" = ../../files/glow/glow.yml;
    "kitty/current-theme.conf" = ../../files/kitty/current-theme.conf;
    "kitty/kitty.conf" = ../../files/kitty/kitty.conf;
    "linearmouse/linearmouse.json" = ../../files/linearmouse/linearmouse.json;
    "mise/config.toml" = ../../files/mise/config.toml;
    "starship.toml" = ../../files/starship.toml;
    "tmux/os-icon.sh" = ../../files/tmux/os-icon.sh;
  };

  # Ghostty advertises itself as xterm-ghostty by default, but most terminfo
  # databases don't ship that entry, so provide it in ~/.terminfo for SSH
  # sessions from Ghostty on any managed host. Layout gotcha: GNU ncurses
  # (Linux) hashes terminfo dirs by first letter ("x/"), while BSD ncurses
  # (macOS) hashes by hex char code ("78/") — both in the package output we
  # read from and in the ~/.terminfo lookup — so pick the right source per
  # platform and deploy under both names.
  ghosttyTerminfoSource =
    if pkgs.stdenv.hostPlatform.isDarwin && pkgs ? ghostty-bin then
      "${pkgs.ghostty-bin.terminfo}/share/terminfo/78/xterm-ghostty"
    else
      "${pkgs.ghostty.terminfo}/share/terminfo/x/xterm-ghostty";

  prepareLinks = import ../../lib/prepare-links.nix { inherit lib pkgs; };
in
{
  home.file.".terminfo/x/xterm-ghostty" = {
    source = ghosttyTerminfoSource;
  };
  home.file.".terminfo/78/xterm-ghostty" = {
    source = ghosttyTerminfoSource;
  };

  home.activation.prepareManagedConfigLinks =
    lib.hm.dag.entryBetween [ "linkGeneration" ] [ "checkLinkTargets" ]
      (
        prepareLinks (
          lib.mapAttrs' (
            name: source: lib.nameValuePair "${config.xdg.configHome}/${name}" source
          ) managedXdgConfig
        )
      );

  xdg.configFile =
    lib.mapAttrs (_name: source: {
      inherit source;
      force = true;
    }) managedXdgConfig
    // {
      "tmux/os-icon.sh" = {
        source = managedXdgConfig."tmux/os-icon.sh";
        force = true;
        executable = true;
      };
    };

  # macOS glow reads its config from ~/Library/Preferences instead of XDG.
  home.file."Library/Preferences/glow/glow.yml" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    source = managedXdgConfig."glow/glow.yml";
    force = true;
  };
}
