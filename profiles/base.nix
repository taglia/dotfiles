{
  pkgs,
  agenix,
  user,
  ...
}:

{
  imports = [
    ../modules/shells.nix
    ../modules/tmux.nix
    ../modules/vim/default.nix
  ];

  # Avoid Home Manager's generated option manual, which can trigger
  # context warnings for options.json on newer Nix versions.
  manual.manpages.enable = false;

  programs.mise = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.git = {
    enable = true;

    settings.user.name = user.githubUsername;
    settings.user.email = user.email;
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
      cmake
      fx
      gitleaks
      glow
      sqlite
      nmap
      hdf5
      hugo
      hub
      links2
      mosh
      pandoc
      pwgen
      sc-im
      tabiew
      unar

      # Fun
      asciiquarium
      cmatrix
      nethack

      # Security
      lynis

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
      (python3.withPackages (python-pkgs: [
        python-pkgs.pip
      ]))
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
