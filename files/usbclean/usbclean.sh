#!/usr/bin/env bash
# usbclean: strip the metadata macOS leaves on a removable volume, then eject
# it so nothing can be written back.
#
# Packaged by modules/home/darwin-apps.nix (writeShellApplication, which adds
# `set -o errexit -o nounset -o pipefail`); the options are repeated here so
# the file behaves the same when run directly.
set -euo pipefail

# Tool paths are absolute: the user's PATH puts Nix's GNU find/stat ahead of
# the BSD ones this script is written against.
diskutil=/usr/sbin/diskutil
plutil=/usr/bin/plutil
find=/usr/bin/find
stat=/usr/bin/stat

# Removed from the root of the volume only.
root_items=(
  .Spotlight-V100
  .Trashes
  .fseventsd
  .TemporaryItems
  .DocumentRevisions-V100
  .apdisk
)

usage() {
  cat <<'EOF'
Usage: usbclean [-n] [-k] [-f] VOLUME
       usbclean [-f]

Remove macOS metadata from an external volume, then eject it. Without a
VOLUME nothing is removed: the volumes that can be cleaned are listed.

  VOLUME  a volume name ("STICK"), its mount point ("/Volumes/STICK"), or any
          path on it

  -n, --dry-run   list what would be removed; change nothing, do not eject
  -k, --keep      clean but leave the volume mounted (macOS will recreate
                  some of the files, typically within seconds)
  -f, --force     also accept (and list) APFS / HFS+ volumes (see below)
  -h, --help      show this help

Removed everywhere on the volume: .DS_Store and AppleDouble "._*" files.
Removed from its root: .Spotlight-V100, .Trashes, .fseventsd, .TemporaryItems,
.DocumentRevisions-V100, .apdisk.

Removing .Trashes permanently deletes whatever is in the Trash on that volume.
Internal disks are always refused. APFS / HFS+ volumes are refused without
--force: on a Mac-formatted disk these directories hold the Trash, document
versions and the Spotlight index, which are usually worth keeping.
EOF
}

die() {
  printf 'usbclean: %s\n' "$*" >&2
  exit 1
}

dry_run=0
keep=0
force=0
target=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n | --dry-run) dry_run=1 ;;
    -k | --keep | --no-eject) keep=1 ;;
    -f | --force) force=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      [[ $# -le 1 ]] || die "expected at most one volume"
      target="${1:-}"
      break
      ;;
    -*) die "unknown option: $1 (see --help)" ;;
    *)
      [[ -z "$target" ]] || die "expected at most one volume"
      target="$1"
      ;;
  esac
  shift
done

# plist_get PLIST KEY: print a top-level value, or nothing if the key is absent.
plist_get() {
  "$plutil" -extract "$2" raw -o - - <<<"$1" 2>/dev/null || true
}

# volume_info PATH: the `diskutil info` plist of the volume PATH lives on.
volume_info() {
  local device
  device="$("$stat" -f %Sd "$1")" || return 1
  "$diskutil" info -plist "/dev/$device" 2>/dev/null
}

# Mac-formatted volumes are only accepted with --force.
is_mac_filesystem() {
  case "$1" in
    apfs | hfs) return 0 ;;
    *) return 1 ;;
  esac
}

# No volume named: explain and list, never clean. Deleting always takes an
# explicit argument, even when only one volume qualifies.
if [[ -z "$target" ]]; then
  cat <<'EOF'
usbclean removes the metadata macOS leaves on an external volume (.DS_Store,
"._*" files, .Spotlight-V100, .Trashes, .fseventsd, ...) and then ejects it,
so that nothing is written back. Nothing is removed until you name a volume:

  usbclean VOLUME       clean VOLUME, then eject it
  usbclean -n VOLUME    only show what would be removed
  usbclean --help       all options, and exactly what is removed

EOF

  listed=0
  for mount_point in /Volumes/*; do
    [[ -d "$mount_point" && ! -L "$mount_point" ]] || continue
    info="$(volume_info "$mount_point")" || continue
    [[ "$(plist_get "$info" MountPoint)" == "$mount_point" ]] || continue
    [[ "$(plist_get "$info" Internal)" == "false" ]] || continue
    [[ "$(plist_get "$info" WritableVolume)" == "true" ]] || continue
    filesystem="$(plist_get "$info" FilesystemType)"
    if is_mac_filesystem "$filesystem" && [[ "$force" -eq 0 ]]; then
      continue
    fi

    if [[ "$listed" -eq 0 ]]; then
      printf 'Volumes that can be cleaned:\n'
    fi
    listed=$((listed + 1))
    printf '  %s  (%s, /dev/%s)\n' \
      "${mount_point#/Volumes/}" \
      "${filesystem:-unknown filesystem}" \
      "$(plist_get "$info" DeviceIdentifier)"
  done

  if [[ "$listed" -eq 0 ]]; then
    printf 'No external volume that can be cleaned is mounted.\n'
  fi
  if [[ "$force" -eq 0 ]]; then
    printf '\nMac-formatted (APFS / HFS+) volumes are not listed; add --force to include them.\n'
  fi
  exit 0
fi

if [[ ! -e "$target" && "$target" != */* && -d "/Volumes/$target" ]]; then
  target="/Volumes/$target"
fi
[[ -e "$target" ]] || die "no such volume or path: $target"

info="$(volume_info "$target")" || die "cannot identify the volume for: $target"
volume="$(plist_get "$info" MountPoint)"
device="$(plist_get "$info" DeviceIdentifier)"
whole_disk="$(plist_get "$info" ParentWholeDisk)"
filesystem="$(plist_get "$info" FilesystemType)"
name="$(plist_get "$info" VolumeName)"

[[ -n "$volume" && -d "$volume" && -n "$device" ]] || die "cannot identify the volume for: $target"
[[ "$volume" != "/" ]] || die "refusing to clean the system volume"
[[ "$(plist_get "$info" Internal)" == "false" ]] || die "$volume is on an internal disk; refusing"
[[ "$(plist_get "$info" WritableVolume)" == "true" ]] || die "$volume is read-only"
if is_mac_filesystem "$filesystem" && [[ "$force" -eq 0 ]]; then
  die "$volume is $filesystem (Mac-formatted); pass --force if you really want its Trash, versions and Spotlight index removed"
fi

printf 'Volume: %s (%s, %s, /dev/%s)\n' "$volume" "${name:-unnamed}" "${filesystem:-unknown filesystem}" "$device"

removed=0
failed=0

remove() {
  local path="$1"

  if [[ "$dry_run" -eq 1 ]]; then
    printf 'would remove %s\n' "$path"
    removed=$((removed + 1))
  elif /bin/rm -rf -- "$path" 2>/dev/null && [[ ! -e "$path" ]]; then
    removed=$((removed + 1))
  else
    printf 'usbclean: could not remove %s\n' "$path" >&2
    failed=$((failed + 1))
  fi
}

# Everything nested first, pruning the root directories that go wholesale
# below. `-x` keeps find on this volume.
prune_args=()
for item in "${root_items[@]}"; do
  prune_args+=(-path "$volume/$item" -o)
done
unset 'prune_args[${#prune_args[@]}-1]'

while IFS= read -r -d '' path; do
  remove "$path"
done < <(
  "$find" -x "$volume" \
    \( "${prune_args[@]}" \) -prune -o \
    -type f \( -name .DS_Store -o -name '._*' \) -print0 2>/dev/null
)

# The directories Spotlight and fseventsd keep rewriting go last, immediately
# before the unmount, to leave them the smallest window to come back.
for item in "${root_items[@]}"; do
  if [[ -e "$volume/$item" || -L "$volume/$item" ]]; then
    remove "$volume/$item"
  fi
done

if [[ "$dry_run" -eq 1 ]]; then
  printf '%d item(s) would be removed; nothing changed, volume left mounted.\n' "$removed"
  exit 0
fi

printf 'Removed %d item(s).\n' "$removed"

if [[ "$keep" -eq 1 ]]; then
  printf 'Left mounted (--keep); macOS may recreate some of these files.\n'
  [[ "$failed" -eq 0 ]] || exit 1
  exit 0
fi

"$diskutil" unmount "$volume" >/dev/null || die "could not unmount $volume (is a file on it still open?); it is clean but still mounted"

# Eject the device only when this was its last mounted volume, so a second
# partition the user is still working on is not pulled out from under them.
if [[ -n "$whole_disk" ]] && /sbin/mount | /usr/bin/grep -q "^/dev/${whole_disk}s"; then
  printf 'Unmounted %s. Other volumes on %s are still mounted, so the device was not ejected.\n' "$volume" "$whole_disk"
elif [[ -n "$whole_disk" ]] && "$diskutil" eject "$whole_disk" >/dev/null 2>&1; then
  printf 'Ejected %s; safe to remove.\n' "${name:-$volume}"
else
  printf 'Unmounted %s; safe to remove.\n' "${name:-$volume}"
fi

[[ "$failed" -eq 0 ]] || exit 1
