{ config, ... }:

{
  imports = [
    ../modules/home/darwin-apps.nix
  ];

  home.sessionPath = [
    "${config.home.homeDirectory}/.nix-profile/bin"
    "/nix/var/nix/profiles/default/bin"
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];
}
