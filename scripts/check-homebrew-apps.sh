#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
host="${1:-mbp}"

if ! command -v brew >/dev/null 2>&1; then
  echo "error: brew not found on PATH" >&2
  exit 1
fi

if ! command -v nix >/dev/null 2>&1; then
  echo "error: nix not found on PATH" >&2
  exit 1
fi

if ! command -v ruby >/dev/null 2>&1; then
  echo "error: ruby not found on PATH; required to parse Homebrew JSON metadata" >&2
  exit 1
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/check-homebrew-apps.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

brewfile="$tmp_dir/Brewfile"
declared_casks="$tmp_dir/declared-casks"
installed_casks="$tmp_dir/installed-casks"
brew_owned_apps="$tmp_dir/brew-owned-apps"
mas_apps="$tmp_dir/mas-apps"
app_bundles="$tmp_dir/app-bundles"

cd "$repo_root"
nix eval ".#darwinConfigurations.${host}.config.homebrew.brewfile" --raw > "$brewfile"

sed -nE 's/^[[:space:]]*cask[[:space:]]+"([^"]+)".*/\1/p' "$brewfile" | sort -u > "$declared_casks"
brew list --cask -1 2>/dev/null | sort -u > "$installed_casks"

{
  if [[ -s "$installed_casks" ]]; then
    mapfile -t installed_cask_args < "$installed_casks"
    installed_cask_count="${#installed_cask_args[@]}"

    for i in "${!installed_cask_args[@]}"; do
      cask="${installed_cask_args[$i]}"
      printf 'Checking cask %d/%d: %s\n' "$((i + 1))" "$installed_cask_count" "$cask" >&2
      brew info --cask --json=v2 "$cask" |
        ruby -rjson -e '
          json = JSON.parse(STDIN.read)
          json.fetch("casks", []).each do |cask|
            cask.fetch("artifacts", []).each do |artifact|
              next unless artifact.key?("app")

              source = Array(artifact["app"]).first
              target = artifact["target"] || File.join("/Applications", File.basename(source))
              target = target.sub(/\A~/, ENV.fetch("HOME"))
              puts File.expand_path(target).sub(%r{/+\z}, "")
            end
          end
        '
    done
  fi
} | sort -u > "$brew_owned_apps"

find /Applications "$HOME/Applications" \
  -maxdepth 1 \
  -type d \
  -name '*.app' \
  -print 2>/dev/null | sed 's:/*$::' | sort -u > "$app_bundles"

find /Applications "$HOME/Applications" \
  -maxdepth 4 \
  -path '*/Contents/_MASReceipt/receipt' \
  -print 2>/dev/null |
  sed 's:/Contents/_MASReceipt/receipt$::' |
  sort -u > "$mas_apps"

bundle_check_output="$tmp_dir/bundle-check"
bundle_cleanup_output="$tmp_dir/bundle-cleanup"

bundle_check_status=0
brew bundle check --file="$brewfile" >"$bundle_check_output" 2>&1 || bundle_check_status=$?

bundle_cleanup_status=0
brew bundle cleanup --file="$brewfile" >"$bundle_cleanup_output" 2>&1 || bundle_cleanup_status=$?

missing_declared="$tmp_dir/missing-declared-casks"
extra_installed="$tmp_dir/extra-installed-casks"
unmanaged_apps="$tmp_dir/unmanaged-apps"

comm -23 "$declared_casks" "$installed_casks" > "$missing_declared"
comm -13 "$declared_casks" "$installed_casks" > "$extra_installed"
comm -23 "$app_bundles" "$brew_owned_apps" | comm -23 - "$mas_apps" > "$unmanaged_apps"

has_findings=0

echo "Homebrew app compliance report for darwinConfiguration '${host}'"
echo

if [[ "$bundle_check_status" -ne 0 ]]; then
  has_findings=1
  echo "Brewfile is not fully satisfied:"
  sed 's/^/  /' "$bundle_check_output"
  echo
else
  echo "Brewfile is satisfied."
  echo
fi

if [[ -s "$missing_declared" ]]; then
  has_findings=1
  echo "Declared casks not installed:"
  sed 's/^/  - /' "$missing_declared"
  echo
fi

if [[ "$bundle_cleanup_status" -ne 0 || -s "$extra_installed" ]]; then
  has_findings=1
  echo "Installed casks not declared in nix-darwin:"
  if [[ -s "$extra_installed" ]]; then
    sed 's/^/  - /' "$extra_installed"
  else
    sed 's/^/  /' "$bundle_cleanup_output"
  fi
  echo
fi

if [[ -s "$unmanaged_apps" ]]; then
  has_findings=1
  echo "App bundles not owned by Homebrew casks or MAS receipts:"
  sed 's/^/  - /' "$unmanaged_apps"
  echo
fi

if [[ "$has_findings" -eq 0 ]]; then
  echo "No non-compliant Homebrew app state found."
else
  echo "Note: manually installed vendor apps can be legitimate; this script flags them so you can decide whether to add a cask, MAS entry, or leave them unmanaged."
fi

exit "$has_findings"
