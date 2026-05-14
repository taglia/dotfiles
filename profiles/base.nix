{ config, pkgs, lib, ... }:


{
  imports = [
    ../modules/shells.nix
    ../modules/tmux.nix
  ];

  programs.mise = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.git = {
    enable = true;

    settings.user.name = "taglia";
    settings.user.email = "taglia@example.com";
  };

  programs.atuin = {
    enable = true;

    settings = {
      auto_sync = false;
      update_check = false;
      enter_accept = true;
      # sync_frequency = "5m";
    };
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  xdg.configFile."starship.toml".source = ../files/starship.toml;

  home.packages = with pkgs; [
    ripgrep
    fd
    fzf

    git
    curl
    wget
    unzip
    zip

    gcc
    gnumake

    nodejs
    python3
    lua-language-server
    stylua

    nil
    nixfmt-rfc-style

    tmux
    atuin
    fastfetch

    magic-wormhole
  ];
}

