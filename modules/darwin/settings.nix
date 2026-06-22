{
  darwinFeatures ? { },
  lib,
  pkgs,
  user,
  ...
}:

{
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

  power.restartAfterFreeze = true;
  power.restartAfterPowerFailure = lib.mkIf (darwinFeatures.restartAfterPowerFailure or false) true;
  power.sleep.display = 5;

  # Export to the per-user launchd session so GUI apps inherit it too.
  launchd.user.envVariables.XDG_CONFIG_HOME = "/Users/${user.username}/.config";

  system.defaults.NSGlobalDomain = {
    AppleTemperatureUnit = "Celsius";
    AppleShowAllExtensions = true;
    AppleMetricUnits = 1;
    AppleMeasurementUnits = "Centimeters";
    AppleInterfaceStyleSwitchesAutomatically = true;
    AppleICUForce24HourTime = false;
    NSNavPanelExpandedStateForSaveMode = true;
    NSNavPanelExpandedStateForSaveMode2 = true;
  };
  system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;

  # Menubar behavior
  system.defaults.controlcenter = {
    AirDrop = false;
    BatteryShowPercentage = false;
    Bluetooth = false;
    Display = false;
    FocusModes = false;
    NowPlaying = false;
    Sound = false;
  };

  system.defaults.loginwindow = {
    GuestEnabled = false;
    LoginwindowText = "⍺ ω";
    ShutDownDisabledWhileLoggedIn = true;
    RestartDisabledWhileLoggedIn = true;
    PowerOffDisabledWhileLoggedIn = true;
  };
  # nix-darwin does not expose the current-host idle timer that controls when the
  # screensaver starts.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    launchctl asuser "$(id -u -- ${user.username})" sudo --user=${user.username} -- \
      defaults -currentHost write com.apple.screensaver idleTime -int 300
  '';
}
