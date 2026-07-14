{ pkgs, ... }:

{
  # Fonts installed system-wide for macOS apps outside Home Manager. The
  # shared list (lib/fonts.nix) carries the fonts every desktop host needs;
  # the extras here are Darwin-only niceties.
  fonts.packages =
    import ../../lib/fonts.nix pkgs
    ++ (with pkgs; [
      nerd-fonts.dejavu-sans-mono
      nerd-fonts.fira-code
      nerd-fonts.inconsolata
      nerd-fonts.inconsolata-go
      nerd-fonts.iosevka-term-slab
      nerd-fonts.jetbrains-mono
      nerd-fonts.meslo-lg
      nerd-fonts.monofur
    ]);

  # Native Nix packages installed into the nix-darwin system profile.
  #
  # Use this for macOS packages that are available in nixpkgs and make sense as
  # machine-level tools. Prefer Home Manager for user CLI/dev tools, and
  # Homebrew casks for vendor-distributed GUI apps that nixpkgs does not package
  # well on Darwin.
  #
  # 1Password GUI and CLI are kept as Homebrew casks (see
  # `modules/darwin/homebrew.nix`) rather than moved under nix-darwin / Home
  # Manager:
  #
  # - The GUI app refuses to run outside `/Applications`. Home Manager places
  #   apps in `~/Applications/Home Manager Apps`, so HM is out. The nix-darwin
  #   `programs._1password-gui` module works around this by rsync-ing the
  #   `.app` bundle from the Nix store into `/Applications/1Password.app` on
  #   every activation, which is heavier and more fragile than the cask.
  # - 1Password ships frequent updates (often weekly). The Homebrew cask tracks
  #   vendor releases faster than nixpkgs' unfree `_1password-gui`.
  # - 1Password 8 has its own built-in updater; under the nix-darwin module an
  #   in-place self-update would diverge from the Nix-pinned version until the
  #   next `darwin-rebuild switch` re-rsyncs it.
  # - The CLI (`op`) is version-coupled to the desktop app's vault format and
  #   integration features, so both should update together from the same
  #   vendor-managed source.
  #
  # To switch the CLI to nix-darwin anyway, remove the `1password-cli` cask
  # from `modules/darwin/homebrew.nix`, allow the unfree package, and enable
  # the module:
  #
  # nixpkgs.config.allowUnfreePredicate =
  #   pkg: builtins.elem (pkgs.lib.getName pkg) [ "1password-cli" ];
  #
  # programs._1password.enable = true;
  environment.systemPackages = with pkgs; [
    qemu

    # `enableAllTerminfo` currently pulls in removed packages such as `termite`
    # from nixpkgs 26.05, which prevents the Darwin system from evaluating.
    # Keep the terminal entries we actually use here instead.
    ghostty-bin.terminfo
    kitty.terminfo
    wezterm.terminfo
    alacritty.terminfo
  ];

  # See note above: disabled to avoid pulling removed terminfo packages.
  environment.enableAllTerminfo = false;
}
