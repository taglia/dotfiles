{
  lib,
  pkgs,
  user,
  ...
}:

let
  wallpaperDir = "/Users/${user.username}/Pictures/Wallpapers";
  # The activation script pins the chosen wallpaper path here so the
  # LaunchAgent can re-apply the *same* image to hot-plugged displays without
  # re-picking a random one. Lives under the user's state dir, never in the
  # Nix store, so private/paid images stay out of the store and the repo.
  stateDir = "/Users/${user.username}/.local/state/dotfiles";
  stateFile = "${stateDir}/wallpaper";
  logFile = "${stateDir}/wallpaper.log";

  # Reads the pinned wallpaper path and applies it to every currently
  # attached display via `desktoppr`. Shared by the activation script (run
  # as the user through `launchctl asuser`) and the LaunchAgent below (which
  # already runs as the user), so a freshly connected external monitor gets
  # the same image as the built-in panel. `desktoppr` sets all screens when
  # given a single file path; unlike AppleScript's `tell every desktop` it
  # reliably reaches external displays.
  applyWallpaper = pkgs.writeShellScript "wallpaper-apply" ''
    set -eu
    if [ -f "${stateFile}" ]; then
      wallpaper="$(cat "${stateFile}")"
      if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
        echo "applying wallpaper: $wallpaper" >&2
        exec ${pkgs.desktoppr}/bin/desktoppr "$wallpaper"
      fi
    fi
  '';
in
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
    ShowExternalHardDrivesOnDesktop = false;
    ShowHardDrivesOnDesktop = false;
    ShowMountedServersOnDesktop = false;
    ShowPathbar = true;
    ShowRemovableMediaOnDesktop = false;
    ShowStatusBar = true;
    _FXSortFoldersFirst = true;
  };

  # Keep each display on its own Spaces. This is already the macOS default and
  # not required by Aerospace; pinned here only so the setting is explicit.
  # Takes effect after logout.
  system.defaults.spaces.spans-displays = false;

  # Pick a random private local wallpaper on every `darwin-rebuild switch`,
  # pin its path to a state file, and apply it to all displays. The directory
  # is intentionally not a Nix path so paid/private images never enter the
  # store or the public repository. The random pick happens only here (on
  # switch); the LaunchAgent below re-applies the *pinned* path on display
  # changes without re-picking.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    if [ -d "${wallpaperDir}" ]; then
      wallpaper="$(
        /usr/bin/find "${wallpaperDir}" -type f \( \
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
        # Pin the chosen path so the LaunchAgent can re-apply it later.
        launchctl asuser "$(id -u -- ${user.username})" sudo --user=${user.username} -- \
          /bin/sh -c 'mkdir -p "$1" && printf "%s\n" "$2" > "$3"' _ \
          "${stateDir}" "$wallpaper" "${stateFile}"
        launchctl asuser "$(id -u -- ${user.username})" sudo --user=${user.username} -- \
          ${applyWallpaper}
      fi
    fi
  '';

  # Re-apply the pinned wallpaper when the display configuration changes
  # (e.g. docking an external monitor) and at login. This is the fix for the
  # external-monitor gap: macOS gives a hot-plugged display its own Space with
  # the default wallpaper, and the one-shot activation script above never
  # re-runs, so the external stayed on the system default.
  #
  # No background process is left running: launchd keeps the job *loaded*
  # (just a plist, no process) and only spawns `applyWallpaper` momentarily
  # on the triggers below, after which it exits. `WatchPaths` fires when the
  # windowserver rewrites its display-state plist on connect/disconnect; this
  # was confirmed to change on hot-plug on this machine. `RunAtLoad` covers
  # login and the initial `darwin-rebuild switch` load.
  environment.userLaunchAgents."local.dotfiles.wallpaper.plist".text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>Label</key>
      <string>local.dotfiles.wallpaper</string>
      <key>ProgramArguments</key>
      <array>
        <string>/bin/sh</string>
        <string>-c</string>
        <string>/bin/wait4path /nix/store &amp;&amp; exec ${applyWallpaper}</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
      <key>WatchPaths</key>
      <array>
        <string>/Library/Preferences/com.apple.windowserver.displays.plist</string>
      </array>
      <key>StandardOutPath</key>
      <string>${logFile}</string>
      <key>StandardErrorPath</key>
      <string>${logFile}</string>
      <key>ProcessType</key>
      <string>Background</string>
    </dict>
    </plist>
  '';
}
