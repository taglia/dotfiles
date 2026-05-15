{ pkgs, lib, ... }:

let
  shellAliases = {
    ll = "ls -la";
    la = "ls -A";
    l = "ls -CF";

    gs = "git status";
    gc = "git commit";
    gp = "git push";
    gl = "git pull";
    vim = "nvim";
  };
in
{
  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
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

    loginShellInit = ''
      if test -e ~/.nix-profile/etc/profile.d/nix.fish
        source ~/.nix-profile/etc/profile.d/nix.fish
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
    '';
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.starship = {
    enable = true;
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
}
