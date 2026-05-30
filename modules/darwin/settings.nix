{
  darwinFeatures ? { },
  lib,
  pkgs,
  user,
  ...
}:

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

  system.defaults.CustomUserPreferences = { };
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

  system.defaults.NSGlobalDomain = {
    NSAutomaticPeriodSubstitutionEnabled = false;
    NSAutomaticCapitalizationEnabled = false;
    AppleTemperatureUnit = "Celsius";
    AppleShowAllExtensions = true;
    AppleMetricUnits = 1;
    AppleMeasurementUnits = "Centimeters";
    AppleInterfaceStyleSwitchesAutomatically = true;
    AppleICUForce24HourTime = false;
    "com.apple.keyboard.fnState" = true;
    "com.apple.mouse.tapBehavior" = 1;
    "com.apple.trackpad.forceClick" = true;
  };
  system.defaults.WindowManager = {
    EnableTiledWindowMargins = false;
    EnableTilingByEdgeDrag = false;
  };
  system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;
  system.defaults.controlcenter.FocusModes = true;

  system.defaults.dock = {
    autohide = true;
    autohide-delay = 0.24;
    largesize = 16;
    # Use "left" or "right" here to move the Dock to a screen edge.
    orientation = "bottom";
    persistent-apps = [
      "/Applications/Orion.app"
      "/System/Applications/Mail.app"
      "/Applications/OmniFocus.app"
      "/Applications/1Password.app"
      "/Applications/Ghostty.app"
      "/Applications/ShellFish.app"
      "/Applications/Screens 5.app"
      "/Applications/Drafts.app"
      "/Applications/DEVONthink.app"
      "/Applications/Obsidian.app"
      "/System/Applications/Messages.app"
      "/Applications/Signal.app"
      "/Applications/Ferdium.app"
      "/Applications/Lire.app"
    ];
    persistent-others = [
      {
        folder = {
          path = "/Users/${user.username}/Downloads";
          arrangement = "date-added";
          displayas = "stack";
          showas = "fan";
        };
      }
      {
        folder = {
          path = "/Users/${user.username}/TempSpace";
          arrangement = "name";
          displayas = "stack";
          showas = "automatic";
        };
      }
    ];
    show-recents = true;
    slow-motion-allowed = true;
    wvous-bl-corner = 13;
    wvous-tl-corner = 6;
  };
  system.defaults.finder = {
    AppleShowAllExtensions = true;
    ShowExternalHardDrivesOnDesktop = true;
    ShowHardDrivesOnDesktop = false;
    ShowMountedServersOnDesktop = true;
    ShowPathbar = true;
    ShowRemovableMediaOnDesktop = true;
    ShowStatusBar = true;
    _FXSortFoldersFirst = true;
  };
  system.defaults.iCal = {
    "TimeZone support enabled" = true;
    CalendarSidebarShown = true;
    "first day of week" = "Monday";
  };
  system.defaults.loginwindow = {
    GuestEnabled = false;
    LoginwindowText = "Cesare's computer";
  };
  system.defaults.screensaver = {
    askForPassword = true;
    askForPasswordDelay = 2;
  };
  system.defaults.trackpad = {
    Clicking = true;
    DragLock = true;
    Dragging = true;
    ForceSuppressed = false;
    TrackpadFourFingerHorizSwipeGesture = 2;
    TrackpadPinch = true;
    TrackpadRightClick = true;
    TrackpadRotate = true;
    TrackpadThreeFingerDrag = true;
    TrackpadThreeFingerHorizSwipeGesture = 0;
    TrackpadThreeFingerVertSwipeGesture = 0;
    TrackpadThreeFingerTapGesture = 0;
    TrackpadTwoFingerDoubleTapGesture = true;
    TrackpadTwoFingerFromRightEdgeSwipeGesture = 3;
  };
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToControl = true;
}
