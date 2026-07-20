{ lib, ... }:

let
  mouselessConfig = ../../files/mouseless/config.yaml;

  # Path of the config inside the mouseless sandbox, relative to $HOME. The
  # single source for both the home.file entry and the per-app defaults hook
  # below so the two can never drift. (mouseless reads its config from this
  # sandboxed container path on macOS.)
  mouselessConfigPath = "Library/Containers/net.sonuscape.mouseless/Data/.mouseless/configs/config.yaml";
in

{
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
