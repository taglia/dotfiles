{ pkgs, ... }:

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

      # Catppuccin Mocha. The same palette is duplicated in
      # files/kitty/current-theme.conf, files/starship.toml and
      # files/pi/agent/themes/catppuccin-mocha.json — keep them in sync.
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
}
