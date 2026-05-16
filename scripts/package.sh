#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
repo_name=$(basename -- "$repo_dir")
package_dir="$repo_dir/packages"
archive="$package_dir/dotfiles_$(date +%Y%m%d).tar.gz"

mkdir -p "$package_dir"

tar \
  --exclude="$repo_name/.git" \
  --exclude="$repo_name/packages/*.tar.gz" \
  -czf "$archive" \
  -C "$(dirname -- "$repo_dir")" \
  "$repo_name"

printf '%s\n' "$archive"
