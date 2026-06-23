{
  darwinFeatures ? { },
  lib,
  user,
  ...
}:

{
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
  # Per-app defaults that don't warrant their own module yet.
  system.defaults.iCal = {
    "TimeZone support enabled" = true;
    CalendarSidebarShown = true;
    "first day of week" = "Monday";
  };

  # nix-darwin does not expose the current-host idle timer that controls when the
  # screensaver starts.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    launchctl asuser "$(id -u -- ${user.username})" sudo --user=${user.username} -- \
      defaults -currentHost write com.apple.screensaver idleTime -int 300
  '';
}
