{
  darwinFeatures ? { },
  lib,
  pkgs,
  ...
}:

{
  # This module is the staging area for macOS system preferences and other
  # Darwin-only settings. Keep additions here conservative: prefer settings
  # that are easy to verify, easy to roll back, and clearly machine-level.

  # Fonts installed system-wide by nix-darwin.
  #
  # Add font packages from nixpkgs here when you want them available to macOS
  # apps outside the Home Manager environment.
  #
  # Example:
  #
  # fonts.packages = with pkgs; [
  #   nerd-fonts.hack
  #   nerd-fonts.iosevka
  # ];
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

  # General macOS defaults.
  #
  # These are written with `defaults` during activation. Some changes require
  # logging out, restarting affected apps, or rebooting before they are visible.
  #
  # Example:
  #
  # system.defaults.NSGlobalDomain = {
  #   AppleShowAllExtensions = true;
  #   InitialKeyRepeat = 15;
  #   KeyRepeat = 2;
  # };

  # Finder settings.
  #
  # Example:
  #
  # system.defaults.finder = {
  #   AppleShowAllExtensions = true;
  #   FXEnableExtensionChangeWarning = false;
  #   ShowPathbar = true;
  #   ShowStatusBar = true;
  # };

  # Dock and Mission Control settings.
  #
  # Example:
  #
  # system.defaults.dock = {
  #   autohide = true;
  #   mru-spaces = false;
  #   show-recents = false;
  # };

  # Trackpad, keyboard, and accessibility settings.
  #
  # Example:
  #
  # system.defaults.trackpad = {
  #   Clicking = true;
  #   TrackpadThreeFingerDrag = true;
  # };
  #
  # system.defaults.universalaccess = {
  #   reduceMotion = true;
  # };

  # Screenshots, clock, and other built-in preference domains.
  #
  # Example:
  #
  # system.defaults.screencapture = {
  #   location = "~/Desktop";
  #   type = "png";
  # };
  #
  # system.defaults.menuExtraClock = {
  #   Show24Hour = true;
  #   ShowSeconds = false;
  # };

  # Escape hatch for preference domains that nix-darwin does not expose as
  # typed options yet. Prefer typed `system.defaults.*` options when available.
  #
  # Example:
  #
  # system.defaults.CustomUserPreferences = {
  #   "com.apple.TextEdit" = {
  #     RichText = false;
  #   };
  # };
  system.defaults.CustomUserPreferences = { };

  # Other Darwin-only configuration can live here as it becomes useful:
  #
  # - launchd daemons/agents
  # - networking and firewall preferences
  # - power management
  # - host-specific hardware support
  # - extra activation scripts for settings without nix-darwin options

  # Cesare's options
  environment.systemPackages = with pkgs; [
    ghostty-bin.terminfo
    kitty.terminfo
    wezterm.terminfo
    alacritty.terminfo
  ];

  # `enableAllTerminfo` currently pulls in removed packages such as `termite`
  # from nixpkgs 26.05, which prevents the Darwin system from evaluating.
  # Keep the terminal entries we actually use in `environment.systemPackages`.
  environment.enableAllTerminfo = false;
  # Check nix.gc.* for automated garbage collector
  # Check nix.settings.auto-optimise-store
  power.restartAfterFreeze = true;
  power.restartAfterPowerFailure = lib.mkIf (darwinFeatures.restartAfterPowerFailure or false) true;
  # Check programs._1password*
  # Check programs.fish* and from there onwards
}
