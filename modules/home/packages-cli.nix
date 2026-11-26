{
  lib,
  pkgs,
  inputs,
  ...
}:

{
  home.packages =
    (with pkgs; [
      ripgrep
      fd
      fzf
      jq
      just
      vim
      gnupg
      tree

      curl
      wget
      lftp
      unzip
      zip
      openssl

      fastfetch
      magic-wormhole
      mosh

      lynis
      age
    ])
    # YubiKey Manager CLI (`ykman`). Darwin-only: macOS ships the smart-card
    # stack it talks to (CryptoTokenKit), while on Linux it needs the pcscd
    # system service, which Home Manager cannot provide, and no Linux host
    # here has a YubiKey plugged in. The GUI counterpart is the
    # `yubico-authenticator` cask (modules/darwin/homebrew.nix).
    ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ pkgs.yubikey-manager ]
    ++ [
      inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
}
