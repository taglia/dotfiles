# Shared activation-script snippet: remove a pre-existing real file at each
# managed target when it is byte-identical to the repo source, so Home
# Manager's checkLinkTargets phase does not abort before it can create the
# symlink. Takes an attrset of absolute target path -> source path.
#
# Used by modules/home/xdg-files.nix, modules/home/pi.nix and
# modules/home/darwin-apps.nix. Tool paths come from pkgs (not /usr/bin or
# /bin) so the snippet works on NixOS as well as macOS.
{ lib, pkgs }:
files:
lib.concatStringsSep "\n" (
  lib.mapAttrsToList (target: source: ''
    if [[ -f "${target}" && ! -L "${target}" ]] && ${pkgs.diffutils}/bin/cmp -s ${source} "${target}"; then
      ${pkgs.coreutils}/bin/rm "${target}"
    fi
  '') files
)
