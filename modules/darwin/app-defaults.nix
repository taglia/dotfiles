{ user, ... }:

{
  system.defaults.dock = {
    autohide = true;
    autohide-delay = 0.24;
    largesize = 16;
    # Use "left" or "right" here to move the Dock to a screen edge.
    orientation = "bottom";
    # Stop macOS reordering Spaces by most-recent-use. Aerospace works inside a
    # single Space, so this isn't something it needs; it just keeps native Space
    # behavior deterministic and out of the way.
    mru-spaces = false;
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

  # Keep each display on its own Spaces. This is already the macOS default and
  # not required by Aerospace; pinned here only so the setting is explicit.
  # Takes effect after logout.
  system.defaults.spaces.spans-displays = false;

  system.defaults.iCal = {
    "TimeZone support enabled" = true;
    CalendarSidebarShown = true;
    "first day of week" = "Monday";
  };
}
