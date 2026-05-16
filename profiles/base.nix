{
  pkgs,
  agenix,
  ...
}:

{
  imports = [
    ../modules/shells.nix
    ../modules/tmux.nix
    ../modules/vim/default.nix
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

  programs.yazi.enable = true;

  xdg.configFile."starship.toml".source = ../files/starship.toml;

  home.packages =
    (with pkgs; [
      # Generic CLI
      ripgrep
      fd
      fzf
      jq
      gnupg
      tree

      git
      curl
      wget
      unzip
      zip
      openssl_3

      gcc
      gnumake

      fastfetch
      magic-wormhole

      # Dev tools
      sqlite
      nmap

      # Nix tooling
      nil
      nixfmt-rfc-style

      # Lua / Neovim
      lua-language-server
      stylua

      # JS / TS tooling
      typescript-language-server
      eslint
      prettierd

      # Python tooling
      pyright
      ruff
      black
      uv

      # Go tooling
      gopls
      golangci-lint

      # Rust tooling
      rust-analyzer
      rustfmt
      clippy

      # Encryption
      age
    ])
    ++ [
      agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
}
