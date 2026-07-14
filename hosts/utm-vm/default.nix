{ lib, user, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ../../modules/nixos/base.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/qemu-guest.nix
  ];

  # Bootloader (UEFI / systemd-boot). Lives with the host because it's tied to
  # how this specific machine boots.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "utm-vm";

  # VM conveniences: skip the login screen and never lock the session. Kept
  # here (not in desktop.nix) so physical/other hosts keep their normal login
  # and lock behaviour. These are dconf *defaults*, not locked, so the user can
  # still re-enable locking from within GNOME if they ever want to.
  services.displayManager.autoLogin = {
    enable = true;
    user = user.username;
  };

  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/desktop/screensaver" = {
          lock-enabled = false;
          lock-delay = lib.gvariant.mkUint32 0;
        };
        "org/gnome/desktop/session" = {
          idle-delay = lib.gvariant.mkUint32 0;
        };
      };
    }
  ];

  # The NixOS release this machine was first installed from. Leave it alone even
  # as the flake's nixpkgs moves forward.
  system.stateVersion = "26.05";
}
