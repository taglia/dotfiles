{ ... }:

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

  # The NixOS release this machine was first installed from. Leave it alone even
  # as the flake's nixpkgs moves forward.
  system.stateVersion = "26.05";
}
