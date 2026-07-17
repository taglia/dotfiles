{
  lib,
  user,
  ...
}:

{
  power.restartAfterFreeze = true;
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
  system.defaults.NSGlobalDomain._HIHideMenuBar = true;
  system.defaults.universalaccess.reduceTransparency = true; # This is wider than the menubar, but unfortunately it's the only setting affecting it.
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

  # nix-darwin does not expose the current-host idle timer that controls when
  # the screensaver starts. idleTime = 0 disables the screensaver entirely: the
  # desktop (wallpaper) stays visible until the display sleeps
  # (power.sleep.display = 5), and the login window appears on wake because
  # askForPassword is on. No screensaver animation is ever shown; the screen
  # still locks at the 5-minute display-sleep boundary.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    launchctl asuser "$(id -u -- ${user.username})" sudo --user=${user.username} -- \
      defaults -currentHost write com.apple.screensaver idleTime -int 0
    # Require the password immediately on wake (no grace window) so the login
    # screen shows as soon as the display wakes from sleep.
    launchctl asuser "$(id -u -- ${user.username})" sudo --user=${user.username} -- \
      defaults write com.apple.screensaver askForPasswordDelay -int 0
  '';
}
