{
  pkgs,
  lib,
  ...
}:

let
  catppuccin = import ../../lib/catppuccin.nix;
  inherit (catppuccin) palette;

  # Single source of truth for the static config files we link into XDG config.
  # Keys are paths relative to xdg.configHome; values are the repo sources.
  managedXdgConfig = {
    "btop/btop.conf" = ../../files/btop/btop.conf;
    "ghostty/config" = ../../files/ghostty/config;
    "ghostty/shaders" = ../../files/ghostty/shaders;
    "glow/glow.yml" = ../../files/glow/glow.yml;
    "kitty/kitty.conf" = ../../files/kitty/kitty.conf;
    "linearmouse/linearmouse.json" = ../../files/linearmouse/linearmouse.json;
    "mise/config.toml" = ../../files/mise/config.toml;
    "starship.toml" = ../../files/starship.toml;
    "tmux/os-icon.sh" = ../../files/tmux/os-icon.sh;
  };

  # Extra xdg.configFile attributes for specific entries, merged over the
  # defaults applied to every managed file.
  entryExtra = {
    "tmux/os-icon.sh" = {
      executable = true;
    };
  };

  # Files whose contents are derived from the shared Catppuccin palette
  # (lib/catppuccin.nix). starship.toml keeps its non-palette config in
  # files/starship.toml and gets the palette table appended; the kitty theme
  # is generated wholesale (it is nothing but palette mappings).
  generatedXdgConfig = {
    "starship.toml".text = ''
      ${builtins.readFile ../../files/starship.toml}
      [palettes.catppuccin_mocha]
      ${lib.concatStringsSep "\n" (map (name: ''${name} = "#${palette.${name}}"'') catppuccin.names)}
    '';

    # Layout mirrors the upstream Catppuccin kitty port
    # (https://github.com/catppuccin/kitty/blob/main/themes/mocha.conf).
    "kitty/current-theme.conf".text = ''
      # vim:ft=kitty

      ## name:     Catppuccin-Mocha
      ## upstream: https://github.com/catppuccin/kitty/blob/main/themes/mocha.conf

      # GENERATED from lib/catppuccin.nix by modules/home/xdg-files.nix —
      # do not edit by hand.

      # The basic colors
      foreground              #${palette.text}
      background              #${palette.base}
      selection_foreground    #${palette.base}
      selection_background    #${palette.rosewater}

      # Cursor colors
      cursor                  #${palette.rosewater}
      cursor_text_color       #${palette.base}

      # URL underline color when hovering with mouse
      url_color               #${palette.rosewater}

      # Kitty window border colors
      active_border_color     #${palette.lavender}
      inactive_border_color   #${palette.overlay0}
      bell_border_color       #${palette.yellow}

      # OS Window titlebar colors
      wayland_titlebar_color system
      macos_titlebar_color system

      # Tab bar colors
      active_tab_foreground   #${palette.crust}
      active_tab_background   #${palette.mauve}
      inactive_tab_foreground #${palette.text}
      inactive_tab_background #${palette.mantle}
      tab_bar_background      #${palette.crust}

      # Colors for marks (marked text in the terminal)
      mark1_foreground #${palette.base}
      mark1_background #${palette.lavender}
      mark2_foreground #${palette.base}
      mark2_background #${palette.mauve}
      mark3_foreground #${palette.base}
      mark3_background #${palette.sapphire}

      # The 16 terminal colors

      # black
      color0 #${palette.surface1}
      color8 #${palette.surface2}

      # red
      color1 #${palette.red}
      color9 #${palette.red}

      # green
      color2  #${palette.green}
      color10 #${palette.green}

      # yellow
      color3  #${palette.yellow}
      color11 #${palette.yellow}

      # blue
      color4  #${palette.blue}
      color12 #${palette.blue}

      # magenta
      color5  #${palette.pink}
      color13 #${palette.pink}

      # cyan
      color6  #${palette.teal}
      color14 #${palette.teal}

      # white
      color7  #${palette.subtext1}
      color15 #${palette.subtext0}
    '';
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
in
{
  home.file.".terminfo/x/xterm-ghostty" = {
    source = ghosttyTerminfoSource;
  };
  home.file.".terminfo/78/xterm-ghostty" = {
    source = ghosttyTerminfoSource;
  };

  # Every entry uses `force = true`, so Home Manager's checkLinkTargets skips
  # the collision check and linkGeneration simply replaces any pre-existing
  # file (it also skips byte-identical targets on its own).
  xdg.configFile =
    lib.mapAttrs (
      name: source:
      {
        inherit source;
        force = true;
      }
      // (entryExtra.${name} or { })
    ) managedXdgConfig
    // lib.mapAttrs (_: entry: entry // { force = true; }) generatedXdgConfig;

  # macOS glow reads its config from ~/Library/Preferences instead of XDG.
  home.file."Library/Preferences/glow/glow.yml" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    source = managedXdgConfig."glow/glow.yml";
    force = true;
  };
}
