{ pkgs, ... }:

{
  # Native Nix packages installed into the nix-darwin system profile.
  #
  # Use this for macOS packages that are available in nixpkgs and make sense as
  # machine-level tools. Prefer Home Manager for user CLI/dev tools, and
  # Homebrew casks for vendor-distributed GUI apps that nixpkgs does not package
  # well on Darwin.
  environment.systemPackages = with pkgs; [
    # Example:
    #
    # ghostty
    #
    # `ghostty` is currently Linux-only in the locked nixpkgs revision, so keep
    # it managed as a Homebrew cask until nixpkgs supports it on Darwin.
  ];
}
