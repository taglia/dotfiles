{ pkgs, ... }:

{
  # Fonts installed system-wide for macOS apps outside Home Manager.
  fonts.packages = with pkgs; [
    nerd-fonts.dejavu-sans-mono
    nerd-fonts.fira-code
    nerd-fonts.inconsolata
    nerd-fonts.inconsolata-go
    nerd-fonts.iosevka
    nerd-fonts.iosevka-term
    nerd-fonts.iosevka-term-slab
    nerd-fonts.jetbrains-mono
    nerd-fonts.meslo-lg
    nerd-fonts.monofur
  ];

  # Native Nix packages installed into the nix-darwin system profile.
  #
  # Use this for macOS packages that are available in nixpkgs and make sense as
  # machine-level tools. Prefer Home Manager for user CLI/dev tools, and
  # Homebrew casks for vendor-distributed GUI apps that nixpkgs does not package
  # well on Darwin.
  #
  # 1Password CLI is currently kept as the `1password-cli` Homebrew cask so it
  # updates with the vendor-managed app. To switch it to nix-darwin, remove the
  # `1password-cli` cask from `modules/darwin/homebrew.nix`, allow the unfree
  # package, and enable the module:
  #
  # nixpkgs.config.allowUnfreePredicate =
  #   pkg: builtins.elem (pkgs.lib.getName pkg) [ "1password-cli" ];
  #
  # programs._1password.enable = true;
  environment.systemPackages = with pkgs; [
    qemu
  ];
}
