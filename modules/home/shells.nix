{
  config,
  pkgs,
  lib,
  ...
}:

let
  vim = "${pkgs.vim}/bin/vim";
  stableNixpkgs = "github:NixOS/nixpkgs/nixos-26.05";
  unstableNixpkgs = "github:NixOS/nixpkgs/nixos-unstable";

  shellAliases = {
    ll = "ls -la";
    la = "ls -A";
    l = "ls -CF";

    vi = vim;
    vim = vim;
    vimdiff = "${vim} -d";
  };

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
  };

  # Ghostty advertises itself as xterm-ghostty by default, but most terminfo
  # databases only ship the entry under the name "ghostty". Provide an alias
  # at ~/.terminfo/x/xterm-ghostty so SSH sessions from Ghostty work on any
  # managed host (NixOS, Darwin, or Nix-managed Debian/Ubuntu).
  ghosttyTerminfo =
    if pkgs.stdenv.hostPlatform.isDarwin && pkgs ? ghostty-bin then
      pkgs.ghostty-bin.terminfo
    else
      pkgs.ghostty.terminfo;

  # Remove a pre-existing real file at the target so Home Manager's
  # checkLinkTargets phase does not abort before it can create the symlink.
  prepareManagedConfigLinks = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: source:
      let
        target = "${config.xdg.configHome}/${name}";
      in
      ''
        if [[ -e "${target}" && ! -L "${target}" ]] && /usr/bin/cmp -s ${source} "${target}"; then
          /bin/rm "${target}"
        fi
      ''
    ) managedXdgConfig
  );
in
{
  home.file.".terminfo/x/xterm-ghostty" = {
    source = "${ghosttyTerminfo}/share/terminfo/g/ghostty";
  };

  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = vim;
    VISUAL = vim;
    LANG = "en_US.UTF-8";
    # Intentionally no LC_ALL: it overrides every per-category LC_* setting
    # (e.g. NixOS's en_SG formatting for time/paper/measurement). LANG alone is
    # the fallback for any category the system doesn't set, so this keeps US
    # English messages while letting system locale settings apply.
    XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
  };

  programs.bash = {
    enable = true;
    inherit shellAliases;
  };

  programs.zsh = {
    enable = true;
    inherit shellAliases;
  };

  programs.fish = {
    enable = true;

    inherit shellAliases;

    plugins = [
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }
    ];

    # Source Nix's fish integration when available so NIX_PROFILES, MANPATH,
    # XDG_DATA_DIRS, etc. match the active Nix installation.
    shellInit = ''
      if test -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
          source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
      end

      function run_stable
          if test (count $argv) -eq 0
              echo "usage: run_stable PACKAGE [ARGS...]"
              return 2
          end
          set -l package $argv[1]
          set -e argv[1]
          nix run "${stableNixpkgs}#$package" -- $argv
      end

      function run_unstable
          if test (count $argv) -eq 0
              echo "usage: run_unstable PACKAGE [ARGS...]"
              return 2
          end
          set -l package $argv[1]
          set -e argv[1]
          nix run "${unstableNixpkgs}#$package" -- $argv
      end

      function shell_stable
          if test (count $argv) -eq 0
              echo "usage: shell_stable PACKAGE [PACKAGE...]"
              return 2
          end
          set -l packages
          for package in $argv
              set -a packages "${stableNixpkgs}#$package"
          end
          nix shell $packages
      end

      function shell_unstable
          if test (count $argv) -eq 0
              echo "usage: shell_unstable PACKAGE [PACKAGE...]"
              return 2
          end
          set -l packages
          for package in $argv
              set -a packages "${unstableNixpkgs}#$package"
          end
          nix shell $packages
      end
    '';

    loginShellInit = ''
      if test -e ~/.nix-profile/etc/profile.d/nix.fish
          source ~/.nix-profile/etc/profile.d/nix.fish
      end
      fish_add_path --move --prepend --path \
          $HOME/.nix-profile/bin \
          /etc/profiles/per-user/$USER/bin \
          /run/current-system/sw/bin \
          /nix/var/nix/profiles/default/bin

      # On NixOS the prepend above would push /run/wrappers/bin below
      # /run/current-system/sw/bin, which also ships a (non-setuid) sudo and
      # would shadow the real setuid wrapper. Keep the wrappers dir first.
      if test -d /run/wrappers/bin
          fish_add_path --move --prepend --path /run/wrappers/bin
      end
    '';

    interactiveShellInit = ''
      fish_vi_key_bindings
      fastfetch
      set fish_greeting
      set -g fish_color_normal cdd6f4
      set -g fish_color_command 89b4fa
      set -g fish_color_param f2cdcd
      set -g fish_color_keyword f38ba8
      set -g fish_color_quote a6e3a1
      set -g fish_color_redirection f5c2e7
      set -g fish_color_end fab387
      set -g fish_color_comment 7f849c
      set -g fish_color_error f38ba8
      set -g fish_color_gray 6c7086
      set -g fish_color_selection --background=313244
      set -g fish_color_search_match --background=313244
      set -g fish_color_option a6e3a1
      set -g fish_color_operator f5c2e7
      set -g fish_color_escape eba0ac
      set -g fish_color_autosuggestion 6c7086
      set -g fish_color_cancel f38ba8
      set -g fish_color_cwd f9e2af
      set -g fish_color_user 94e2d5
      set -g fish_color_host 89b4fa
      set -g fish_color_host_remote a6e3a1
      set -g fish_color_status f38ba8

      set -g fish_pager_color_progress 6c7086
      set -g fish_pager_color_prefix f5c2e7
      set -g fish_pager_color_completion cdd6f4
      set -g fish_pager_color_description 6c7086

      # Feed Starship's right prompt with either the current time or, briefly
      # after a slow command, when it started and how long it took.
      set -gx STARSHIP_RIGHT_STATUS (date '+%H:%M')

      function __starship_command_started --on-event fish_preexec
        set -gx STARSHIP_COMMAND_CURRENT_STARTED_AT (date '+%H:%M')
      end

      function __starship_command_finished --on-event fish_postexec
        if set -q STARSHIP_COMMAND_CURRENT_STARTED_AT; and set -q CMD_DURATION; and test "$CMD_DURATION" -ge 1000 2>/dev/null
          set -l seconds (math --scale=0 "$CMD_DURATION / 1000")
          set -gx STARSHIP_RIGHT_STATUS "run at $STARSHIP_COMMAND_CURRENT_STARTED_AT, took "$seconds"s"
          set -gx STARSHIP_RIGHT_STATUS_FROM_COMMAND 1
        else
          set -gx STARSHIP_RIGHT_STATUS (date '+%H:%M')
          set -e STARSHIP_RIGHT_STATUS_FROM_COMMAND
        end

        set -e STARSHIP_COMMAND_CURRENT_STARTED_AT
      end

      function __starship_refresh_right_status --on-event fish_prompt
        if set -q STARSHIP_RIGHT_STATUS_FROM_COMMAND
          set -e STARSHIP_RIGHT_STATUS_FROM_COMMAND
        else
          set -gx STARSHIP_RIGHT_STATUS (date '+%H:%M')
        end
      end
    '';
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.starship = {
    enable = true;
  };

  home.activation.prepareManagedConfigLinks =
    lib.hm.dag.entryBetween [ "linkGeneration" ] [ "checkLinkTargets" ]
      prepareManagedConfigLinks;

  xdg.configFile = lib.mapAttrs (_name: source: {
    inherit source;
    force = true;
  }) managedXdgConfig;

  # macOS glow reads its config from ~/Library/Preferences instead of XDG.
  home.file."Library/Preferences/glow/glow.yml" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    source = managedXdgConfig."glow/glow.yml";
    force = true;
  };

  programs.atuin = {
    enable = true;

    settings = {
      auto_sync = lib.mkDefault false;
      update_check = false;
      enter_accept = true;
      # sync_frequency = "5m";
    };
  };

  programs.mise = {
    enable = true;

    enableFishIntegration = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  programs.btop.enable = true;
  programs.htop.enable = true;

  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
  };

  programs.bat.enable = true;
}
