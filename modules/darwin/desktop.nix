{ lib, user, ... }:

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
      "/Applications/rootshell.app"
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

  # Use a random private local wallpaper when available. The directory is
  # intentionally not a Nix path so paid/private images never enter the store or
  # the public repository.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    wallpaper_dir="/Users/${user.username}/Pictures/Wallpapers"

    if [ -d "$wallpaper_dir" ]; then
      wallpaper="$(
        /usr/bin/find "$wallpaper_dir" -type f \( \
          -iname '*.jpg' -o \
          -iname '*.jpeg' -o \
          -iname '*.png' -o \
          -iname '*.heic' -o \
          -iname '*.webp' \
        \) | /usr/bin/sort | /usr/bin/awk '
          BEGIN { srand() }
          { lines[NR] = $0 }
          END { if (NR > 0) print lines[int(rand() * NR) + 1] }
        '
      )"

      if [ -n "$wallpaper" ]; then
        echo >&2 "setting random wallpaper: $wallpaper"
        launchctl asuser "$(id -u -- ${user.username})" sudo --user=${user.username} -- \
          /usr/bin/osascript - "$wallpaper" <<'APPLESCRIPT'
    on run argv
      set wallpaperPath to item 1 of argv
      tell application "System Events"
        tell every desktop
          set picture to wallpaperPath
        end tell
      end tell
    end run
    APPLESCRIPT
      fi
    fi
  '';
}
