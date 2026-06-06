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
cask_index_json="$tmp_dir/cask-index.json"

cd "$repo_root"
nix eval ".#darwinConfigurations.${host}.config.homebrew.brewfile" --raw > "$brewfile"

sed -nE 's/^[[:space:]]*cask[[:space:]]+"([^"]+)".*/\1/p' "$brewfile" | sort -u > "$declared_casks"
brew list --cask -1 2>/dev/null | sort -u > "$installed_casks"

normalize_path() {
  local path="$1"

  path="${path/#\~/$HOME}"
  ruby -e 'puts File.expand_path(ARGV.fetch(0)).sub(%r{/+\z}, "")' "$path"
}

join_package_path() {
  local volume="$1"
  local location="$2"
  local payload_path="$3"
  local prefix
  local path

  if [[ "$payload_path" = /* ]]; then
    path="$payload_path"
  else
    prefix="${volume%/}"
    if [[ -n "$location" && "$location" != "." && "$location" != "/" ]]; then
      prefix="$prefix/${location#/}"
    fi
    if [[ -z "$prefix" ]]; then
      path="/$payload_path"
    else
      path="$prefix/$payload_path"
    fi
  fi

  normalize_path "$path"
}

package_receipt_apps() {
  local receipt_pattern="$1"
  local receipt
  local volume
  local location
  local app_root
  local candidate
  local candidates=()

  while IFS= read -r receipt; do
    [[ -n "$receipt" ]] || continue

    volume="/"
    location=""
    while IFS=: read -r key value; do
      value="${value# }"
      case "$key" in
        volume) volume="$value" ;;
        location) location="$value" ;;
      esac
    done < <(pkgutil --pkg-info "$receipt" 2>/dev/null || true)

    while IFS= read -r app_root; do
      [[ -n "$app_root" ]] || continue
      candidates=(
        "$(join_package_path "$volume" "$location" "$app_root")"
        "$(normalize_path "/Applications/$(basename "$app_root")")"
        "$(normalize_path "$HOME/Applications/$(basename "$app_root")")"
      )

      for candidate in "${candidates[@]}"; do
        if [[ -d "$candidate" ]]; then
          printf '%s\n' "$candidate"
          break
        fi
      done
    done < <(
      pkgutil --files "$receipt" 2>/dev/null |
        ruby -e '
          ARGF.each_line(chomp: true) do |line|
            app = line[%r{\A(.+?\.app)(?:/|\z)}, 1]
            puts app if app
          end
        ' |
        sort -u
    )
  done < <(pkgutil --pkgs="$receipt_pattern" 2>/dev/null || true)
}

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
              if artifact.key?("app")
                source = Array(artifact["app"]).first
                target = artifact["target"] || File.join("/Applications", File.basename(source))
                target = target.sub(/\A~/, ENV.fetch("HOME"))
                puts ["app", File.expand_path(target).sub(%r{/+\z}, "")].join("\t")
              end

              Array(artifact["uninstall"]).each do |uninstall|
                next unless uninstall.is_a?(Hash)

                Array(uninstall["pkgutil"]).each do |receipt_pattern|
                  puts ["pkgutil", receipt_pattern].join("\t")
                end

                Array(uninstall["delete"]).each do |path|
                  next unless path.to_s.end_with?(".app")

                  path = path.sub(/\A~/, ENV.fetch("HOME"))
                  puts ["app", File.expand_path(path).sub(%r{/+\z}, "")].join("\t")
                end
              end
            end
          end
        ' |
        while IFS=$'\t' read -r artifact_type artifact_value; do
          case "$artifact_type" in
            app) printf '%s\n' "$artifact_value" ;;
            pkgutil) package_receipt_apps "$artifact_value" ;;
          esac
        done
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
unmanaged_app_availability="$tmp_dir/unmanaged-app-availability"

comm -23 "$declared_casks" "$installed_casks" > "$missing_declared"
comm -13 "$declared_casks" "$installed_casks" > "$extra_installed"
comm -23 "$app_bundles" "$brew_owned_apps" | comm -23 - "$mas_apps" > "$unmanaged_apps"

if [[ -s "$unmanaged_apps" ]]; then
  if command -v curl >/dev/null 2>&1 &&
    curl -fsSL --retry 2 --connect-timeout 5 --max-time 30 \
      https://formulae.brew.sh/api/cask.json \
      -o "$cask_index_json"; then
    ruby -rjson -e '
      def normalize(value)
        value
          .downcase
          .sub(/\.app\z/, "")
          .gsub(/&/, " and ")
          .gsub(/\+/, " plus ")
          .gsub(/[^a-z0-9]+/, " ")
          .strip
      end

      def slug(value)
        normalize(value).gsub(/[[:space:]]+/, "-")
      end

      casks = JSON.parse(File.read(ARGV.fetch(0)))
      app_paths = File.readlines(ARGV.fetch(1), chomp: true)
      installed_tokens = File.readlines(ARGV.fetch(2), chomp: true).to_h { |token| [token, true] }

      catalog = casks.map do |cask|
        keys = [cask["token"], *Array(cask["name"])].compact.flat_map do |value|
          [normalize(value), slug(value)]
        end

        Array(cask["artifacts"]).each do |artifact|
          next unless artifact.is_a?(Hash) && artifact.key?("app")

          source = Array(artifact["app"]).first
          target = artifact["target"]
          [source, target].compact.each do |value|
            basename = File.basename(value.to_s, ".app")
            keys << normalize(basename)
            keys << slug(basename)
          end
        end

        {
          token: cask.fetch("token"),
          url: "https://formulae.brew.sh/cask/#{cask.fetch("token")}",
          keys: keys.reject(&:empty?).uniq,
        }
      end

      app_paths.each do |path|
        app_name = File.basename(path, ".app")
        app_keys = [normalize(app_name), slug(app_name)].reject(&:empty?)
        matches = catalog.select { |cask| (cask[:keys] & app_keys).any? }

        if matches.empty?
          puts "#{path}\tHomebrew cask: not found"
        else
          exact = matches.select { |cask| cask[:keys].include?(slug(app_name)) }
          selected = (exact.empty? ? matches : exact).first(3)
          cask_list = selected.map { |cask| "#{cask[:token]} (#{cask[:url]})" }.join(", ")
          suffix = matches.length > selected.length ? ", ..." : ""
          installed = selected.select { |cask| installed_tokens.key?(cask[:token]) }

          if installed.empty?
            puts "#{path}\tHomebrew cask: available as #{cask_list}#{suffix}"
          else
            installed_list = installed.map { |cask| "#{cask[:token]} (#{cask[:url]})" }.join(", ")
            puts "#{path}\tHomebrew cask: installed as #{installed_list}, but this app path is not owned"
          end
        end
      end
    ' "$cask_index_json" "$unmanaged_apps" "$installed_casks" > "$unmanaged_app_availability"
  else
    sed $'s/$/\tHomebrew cask: lookup unavailable/' "$unmanaged_apps" > "$unmanaged_app_availability"
  fi
fi

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
  if [[ -s "$unmanaged_app_availability" ]]; then
    ruby -e '
      unavailable = []
      installed = []
      available = []

      ARGF.each_line(chomp: true) do |line|
        path, status = line.split("\t", 2)
        entry = "  - #{path} (#{status})"

        if status&.start_with?("Homebrew cask: installed as")
          installed << entry
        elsif status&.start_with?("Homebrew cask: available as")
          available << entry
        else
          unavailable << entry
        end
      end

      unless unavailable.empty?
        puts "  Cask unavailable:"
        puts unavailable
      end

      unless installed.empty?
        puts if !unavailable.empty?
        puts "  Cask installed but app path not owned:"
        puts installed
      end

      unless available.empty?
        puts if !unavailable.empty? || !installed.empty?
        puts "  Cask available:"
        puts available
      end
    ' "$unmanaged_app_availability"
  else
    echo "  Cask unavailable:"
    sed 's/^/  - /' "$unmanaged_apps"
  fi
  echo
fi

if [[ "$has_findings" -eq 0 ]]; then
  echo "No non-compliant Homebrew app state found."
else
  echo "Note: manually installed vendor apps can be legitimate; this script flags them so you can decide whether to add a cask, MAS entry, or leave them unmanaged."
fi

exit 0
