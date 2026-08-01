{ modulesPath, ... }:

{
  imports = [
    "${modulesPath}/virtualisation/amazon-image.nix"
    ../../modules/nixos/base.nix
  ];

  # Bootloader (UEFI / systemd-boot). Lives with the host because it's tied to
  # how this specific machine boots.
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = false;

  # The NixOS release this machine was first installed from. Leave it alone even
  # as the flake's nixpkgs moves forward.
  system.stateVersion = "26.05";
}
