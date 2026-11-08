#!/bin/bash
# Raycast script command: open the apps that are wanted on most days but are
# deliberately not launched at login (see startupApps in
# modules/darwin/aerospace.nix), so login stays fast and the rest is one
# Raycast command away. AeroSpace's on-window-detected rules sort the windows.
#
# Installed to ~/.config/raycast/scripts by modules/home/darwin-apps.nix; that
# directory has to be added once under Raycast > Settings > Extensions >
# Script Commands > Add Directories.
#
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Launch Secondary Apps
# @raycast.mode silent
#
# Optional parameters:
# @raycast.icon 🚀
# @raycast.packageName Apps
# @raycast.description Open Mail, Fantastical and Ferdium (whichever are not running yet).
set -u

apps=(
  Mail
  Fantastical
  Ferdium
)

# `open -g` launches without bringing the app to the foreground and is a no-op
# for an app that is already running, so re-running the command is harmless.
failed=()
for app in "${apps[@]}"; do
  open -g -a "$app" 2>/dev/null || failed+=("$app")
done

if [ "${#failed[@]}" -gt 0 ]; then
  echo "Could not open: ${failed[*]}"
  exit 1
fi
echo "Opened ${#apps[@]} apps"
