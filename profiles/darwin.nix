{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    qemu
  ];

  home.sessionPath = [
    "${config.home.homeDirectory}/.nix-profile/bin"
    "/nix/var/nix/profiles/default/bin"
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];
}
