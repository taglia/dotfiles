# Shared wallpaper machinery for macOS. modules/darwin/desktop.nix (random
# pick on every `darwin-rebuild switch`, plus a LaunchAgent that re-applies
# the pinned image on display changes) and modules/home/darwin-apps.nix (the
# `wallpaper-switch` user command) used to carry parallel copies of the picker
# and the state-file protocol; both now come from here. The state file pins
# the chosen path so the LaunchAgent can re-apply the *same* image without
# re-picking. The wallpaper directory is intentionally not a Nix path so
# paid/private images never enter the store or the public repository.
rec {
  # All paths are relative to the user's home directory; each consumer
  # resolves them against its own notion of the user (runtime $HOME for the
  # command, /Users/<username> for the system module).
  wallpaperDirRel = "Pictures/Wallpapers";
  stateDirRel = ".local/state/dotfiles";
  stateFileRel = "${stateDirRel}/wallpaper";

  # Set the desktop wallpaper. With an argument, apply that image; without
  # one, pick a random image from the wallpaper directory (excluding the
  # current one). In both cases the chosen path is pinned to the state file.
  # Tool paths are absolute because the system activation script invokes this
  # with a minimal PATH; `desktoppr` sets all attached screens when given a
  # single file path, which AppleScript's `tell every desktop` does not do
  # reliably for external displays.
  mkSwitchScript =
    pkgs:
    pkgs.writeShellScriptBin "wallpaper-switch" ''
      set -eu

      wallpaperDir="$HOME/${wallpaperDirRel}"
      stateDir="$HOME/${stateDirRel}"
      stateFile="$HOME/${stateFileRel}"

      /bin/mkdir -p "$stateDir"

      if [ $# -gt 0 ]; then
        wallpaper="$1"
        if [ ! -f "$wallpaper" ]; then
          echo "error: file not found: $wallpaper" >&2
          exit 1
        fi
      else
        current=""
        if [ -f "$stateFile" ]; then
          current="$(/bin/cat "$stateFile")"
        fi

        wallpaper="$(
          /usr/bin/find "$wallpaperDir" -type f \( \
            -iname '*.jpg' -o \
            -iname '*.jpeg' -o \
            -iname '*.png' -o \
            -iname '*.heic' -o \
            -iname '*.webp' \
          \) | /usr/bin/sort | /usr/bin/awk -v current="$current" '
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
}
