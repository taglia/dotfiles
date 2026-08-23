{
  lib,
  pkgs,
  ...
}:

let
  mouselessConfig = ../../files/mouseless/config.yaml;

  # Path of the config inside the mouseless sandbox, relative to $HOME. The
  # single source for both the home.file entry and the per-app defaults hook
  # below so the two can never drift. (mouseless reads its config from this
  # sandboxed container path on macOS.)
  mouselessConfigPath = "Library/Containers/net.sonuscape.mouseless/Data/.mouseless/configs/config.yaml";

  # Set the desktop wallpaper, mirroring the logic in
  # modules/darwin/desktop.nix. With an argument, apply that image; without
  # one, pick a random image from ~/Pictures/Wallpapers (excluding the
  # current one). In both cases the chosen path is pinned to the state file
  # so the LaunchAgent in desktop.nix re-applies it after reboot.
  wallpaperSwitch = pkgs.writeShellScriptBin "wallpaper-switch" ''
    set -eu

    wallpaperDir="$HOME/Pictures/Wallpapers"
    stateDir="$HOME/.local/state/dotfiles"
    stateFile="$stateDir/wallpaper"

    mkdir -p "$stateDir"

    if [ $# -gt 0 ]; then
      wallpaper="$1"
      if [ ! -f "$wallpaper" ]; then
        echo "error: file not found: $wallpaper" >&2
        exit 1
      fi
    else
      current=""
      if [ -f "$stateFile" ]; then
        current="$(cat "$stateFile")"
      fi

      wallpaper="$(
        find "$wallpaperDir" -type f \( \
          -iname '*.jpg' -o \
          -iname '*.jpeg' -o \
          -iname '*.png' -o \
          -iname '*.heic' -o \
          -iname '*.webp' \
        \) | sort | awk -v current="$current" '
          BEGIN { srand() }
          {
            all[++total] = $0
            if ($0 != current) lines[++n] = $0
          }
          END {
            if (n > 0) print lines[int(rand() * n) + 1]
            else if (total > 0) print all[int(rand() * total) + 1]
          }
        '
      )"

      if [ -z "$wallpaper" ]; then
        echo "error: no wallpapers found in $wallpaperDir" >&2
        exit 1
      fi
    fi

    printf '%s\n' "$wallpaper" > "$stateFile"
    exec ${pkgs.desktoppr}/bin/desktoppr "$wallpaper"
  '';
in

{
  home.packages = [ wallpaperSwitch ];

  home.shellAliases.wallpaper = "wallpaper-switch";

  home.file.${mouselessConfigPath} = {
    source = mouselessConfig;
    force = true;
  };

  home.activation.configureDarwinAppDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    /usr/bin/defaults write com.superultra.Homerow auto-switch-input-source-id -string com.apple.keylayout.ABC
    /usr/bin/defaults write com.superultra.Homerow disabled-bundle-paths -array \
      "/Applications/1Password.app" \
      "/Applications/1Password%20for%20Safari.app"
    /usr/bin/defaults write com.superultra.Homerow include-beta-updates -bool true
    /usr/bin/defaults write com.superultra.Homerow is-auto-click-enabled -bool false
    /usr/bin/defaults write com.superultra.Homerow launch-at-login -bool true
    /usr/bin/defaults write com.superultra.Homerow non-search-shortcut -string $'\u2325\u21e7Space'
    /usr/bin/defaults write com.superultra.Homerow scroll-shortcut -string $'\u2325\u21e7\u2318J'
    /usr/bin/defaults write com.superultra.Homerow search-shortcut -string $'\u2325\u21e7\u2318Space'
    /usr/bin/defaults write com.superultra.Homerow show-menubar-icon -bool false
    /usr/bin/defaults write com.superultra.Homerow theme-id -string original

    /usr/bin/defaults write net.sonuscape.mouseless "NSStatusItem Preferred Position Item-0" -int 677
  '';
}
