{
  lib,
  pkgs,
  user,
  ...
}:

let
  # Shared with the `wallpaper-switch` user command in
  # modules/home/darwin-apps.nix; lib/wallpaper.nix owns the picker script
  # and the state-file protocol. The state file pins the chosen wallpaper so
  # the LaunchAgent can re-apply the *same* image to hot-plugged displays
  # without re-picking a random one. It lives under the user's state dir,
  # never in the Nix store, so private/paid images stay out of the store and
  # the repo.
  wallpaperLib = import ../../lib/wallpaper.nix;
  wallpaperSwitch = wallpaperLib.mkSwitchScript pkgs;
  wallpaperDir = "/Users/${user.username}/${wallpaperLib.wallpaperDirRel}";
  stateDir = "/Users/${user.username}/${wallpaperLib.stateDirRel}";
  stateFile = "/Users/${user.username}/${wallpaperLib.stateFileRel}";
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
    tilesize = 48;
    appswitcher-all-displays = true;
    autohide-delay = 0.24;
    # Use "left" or "right" here to move the Dock to a screen edge.
    orientation = "bottom";
    # Stop macOS reordering Spaces by most-recent-use. Aerospace works inside a
    # single Space, so this isn't something it needs; it just keeps native Space
    # behavior deterministic and out of the way.
    mru-spaces = false;
    persistent-apps = [
      "/Applications/Orion.app"
      "/Applications/1Password.app"
      "/Applications/Lire.app"
      {
        spacer = {
          small = true;
        };
      }
      "/System/Applications/Mail.app"
      "/Applications/Fantastical.app"
      "/Applications/OmniFocus.app"
      "/Applications/Due.app"
      {
        spacer = {
          small = true;
        };
      }
      "/Applications/rootshell.app"
      "/Applications/Ghostty.app"
      "/Applications/Screens 5.app"
      {
        spacer = {
          small = true;
        };
      }
      "/Applications/Drafts.app"
      "/Applications/DEVONthink.app"
      "/Applications/Obsidian.app"
      {
        spacer = {
          small = true;
        };
      }
      "/System/Applications/Messages.app"
      "/Applications/Signal.app"
      "/Applications/Ferdium.app"
      {
        spacer = {
          small = true;
        };
      }
      "/Applications/Cookie.app"
      "/Applications/AutoMounter.app"
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
    show-recents = false;
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

  # Pick a random private local wallpaper on every `darwin-rebuild switch`
  # (excluding the current one), pin its path to the state file, and apply it
  # to all displays — all via the shared switcher script, run as the user.
  # The random pick happens only here (on switch); the LaunchAgent below
  # re-applies the *pinned* path on display changes without re-picking. A
  # wallpaper failure must not abort the system switch, hence the warning
  # fallback.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    if [ -d "${wallpaperDir}" ]; then
      echo >&2 "setting random wallpaper"
      launchctl asuser "$(id -u -- ${user.username})" sudo --user=${user.username} -- \
        ${wallpaperSwitch}/bin/wallpaper-switch \
        || echo >&2 "warning: wallpaper-switch failed"
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
        <string>${stateFile}</string>
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
