{
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
      diffoscope

      curl
      wget
      lftp
      unzip
      zip
      openssl_3

      fastfetch
      magic-wormhole

      lynis
      age
    ])
    ++ [
      inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
}
