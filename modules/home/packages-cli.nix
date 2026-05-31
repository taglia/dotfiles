{
  pkgs,
  agenix,
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
      unzip
      zip
      openssl_3

      fastfetch
      magic-wormhole

      lynis
      age
    ])
    ++ [
      agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
}
