{ pkgs, lib, ... }:

let
  catppuccin = import ../../lib/catppuccin.nix;
  inherit (catppuccin) palette;

  # fish color slot -> palette name, or { bg = <palette name>; } for slots
  # that set --background= instead of a foreground color.
  fishColors = {
    normal = "text";
    command = "blue";
    param = "flamingo";
    keyword = "red";
    quote = "green";
    redirection = "pink";
    end = "peach";
    comment = "overlay1";
    error = "red";
    gray = "overlay0";
    selection.bg = "surface0";
    search_match.bg = "surface0";
    option = "green";
    operator = "pink";
    escape = "maroon";
    autosuggestion = "overlay0";
    cancel = "red";
    cwd = "yellow";
    user = "teal";
    host = "blue";
    host_remote = "green";
    status = "red";
  };

  fishPagerColors = {
    progress = "overlay0";
    prefix = "pink";
    completion = "text";
    description = "overlay0";
  };

  renderFishColors =
    prefix: colors:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        slot: value:
        if builtins.isString value then
          "set -g fish_${prefix}color_${slot} ${palette.${value}}"
        else
          "set -g fish_${prefix}color_${slot} --background=${palette.${value.bg}}"
      ) colors
    );
in

{
  programs.fish = {
    enable = true;

    plugins = [
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }
    ];

    # Source Nix's fish integration when available so NIX_PROFILES, MANPATH,
    # XDG_DATA_DIRS, etc. match the active Nix installation.
    #
    # The run_*/shell_* helpers use the `n` (stable) and `u` (unstable)
    # registry aliases pinned in profiles/base.nix, so they always match the
    # flake's locked nixpkgs inputs instead of hardcoding a branch name.
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
          nix run "n#$package" -- $argv
      end

      function run_unstable
          if test (count $argv) -eq 0
              echo "usage: run_unstable PACKAGE [ARGS...]"
              return 2
          end
          set -l package $argv[1]
          set -e argv[1]
          nix run "u#$package" -- $argv
      end

      function shell_stable
          if test (count $argv) -eq 0
              echo "usage: shell_stable PACKAGE [PACKAGE...]"
              return 2
          end
          set -l packages
          for package in $argv
              set -a packages "n#$package"
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
              set -a packages "u#$package"
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

      # Catppuccin Mocha, generated from lib/catppuccin.nix (the repo's
      # single source of truth for the palette).
      ${renderFishColors "" fishColors}

      ${renderFishColors "pager_" fishPagerColors}

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
}
