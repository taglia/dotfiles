#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ ! -f "flake.nix" ]]; then
  echo "error: expected to run from a Nix flake repo (missing flake.nix)" >&2
  exit 1
fi

target=""
backup_mode="prompt"
backup_extension=""

usage() {
  cat <<'EOF'
Usage: ./scripts/bootstrap.sh [--target <name>] [--backup[ <extension>] | --backup-extension <extension> | --no-backup]

Runs Home Manager from a flake in this repo.

--target  Home Manager configuration name from flake.nix (homeConfigurations.*)
          If omitted, auto-detects based on OS + arch.
--backup  Back up conflicting files during Home Manager activation.
          If no extension is provided, uses a timestamped backup extension.
--backup-extension <extension>
          Same as --backup <extension>.
--no-backup
          Do not pass Home Manager's backup option.
EOF
}

timestamped_backup_extension() {
  date +"backup-%Y%m%d-%H%M%S"
}

validate_backup_extension() {
  local extension="$1"

  if [[ -z "$extension" ]]; then
    echo "error: backup extension cannot be empty" >&2
    exit 2
  fi

  if [[ "$extension" == */* ]]; then
    echo "error: backup extension must not contain '/'" >&2
    exit 2
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "error: --target requires a value" >&2
        usage >&2
        exit 2
      fi
      target="${2:-}"
      shift 2
      ;;
    --backup)
      backup_mode="enabled"
      if [[ $# -ge 2 && "${2:-}" != -* ]]; then
        backup_extension="${2:-}"
        shift 2
      else
        shift
      fi
      ;;
    --backup-extension)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "error: --backup-extension requires a value" >&2
        usage >&2
        exit 2
      fi
      backup_mode="enabled"
      backup_extension="${2:-}"
      shift 2
      ;;
    --no-backup)
      backup_mode="disabled"
      backup_extension=""
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown arg: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -n "$backup_extension" ]]; then
  validate_backup_extension "$backup_extension"
fi

if ! command -v nix >/dev/null 2>&1; then
  cat >&2 <<'EOF'
error: nix not found on PATH.

Install Nix first (example):
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install
EOF
  exit 1
fi

ensure_flakes_enabled() {
  # Prefer /etc/nix/nix.conf when it exists (common for multi-user installs).
  # Fall back to ~/.config/nix/nix.conf for single-user setups.
  local desired="extra-experimental-features = nix-command flakes"

  has_required_features() {
    local file="$1"
    grep -qE '^[[:space:]]*(extra-)?experimental-features[[:space:]]*=.*\bnix-command\b' "$file" \
      && grep -qE '^[[:space:]]*(extra-)?experimental-features[[:space:]]*=.*\bflakes\b' "$file"
  }

  if [[ -f /etc/nix/nix.conf ]] || [[ -d /etc/nix ]]; then
    if [[ ! -f /etc/nix/nix.conf ]]; then
      echo "info: creating /etc/nix/nix.conf (requires sudo)"
      sudo mkdir -p /etc/nix
      echo "$desired" | sudo tee /etc/nix/nix.conf >/dev/null
      return 0
    fi

    if ! sudo bash -c "$(declare -f has_required_features); has_required_features /etc/nix/nix.conf"; then
      echo "info: enabling flakes in /etc/nix/nix.conf (requires sudo)"
      echo "$desired" | sudo tee -a /etc/nix/nix.conf >/dev/null
    fi
    return 0
  fi

  mkdir -p "$HOME/.config/nix"
  if [[ ! -f "$HOME/.config/nix/nix.conf" ]]; then
    echo "$desired" >"$HOME/.config/nix/nix.conf"
    return 0
  fi

  if ! has_required_features "$HOME/.config/nix/nix.conf"; then
    echo "$desired" >>"$HOME/.config/nix/nix.conf"
  fi
}

auto_target() {
  local os arch
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"

  case "$os" in
    darwin)
      # flake.nix uses aarch64-darwin, which is Apple Silicon.
      echo "apple"
      ;;
    linux)
      case "$arch" in
        x86_64) echo "linux-x86" ;;
        aarch64|arm64) echo "linux-arm" ;;
        *)
          echo "error: unsupported arch for auto-detect: $arch" >&2
          echo "hint: pass --target explicitly (see flake.nix homeConfigurations)" >&2
          exit 2
          ;;
      esac
      ;;
    *)
      echo "error: unsupported OS for auto-detect: $os" >&2
      echo "hint: pass --target explicitly (see flake.nix homeConfigurations)" >&2
      exit 2
      ;;
  esac
}

ensure_flakes_enabled

if [[ -z "$target" ]]; then
  target="$(auto_target)"
fi

home_manager_args=(switch --flake ".#${target}")

if [[ "$backup_mode" == "prompt" ]]; then
  if [[ -t 0 && -t 1 ]]; then
    backup_extension="$(timestamped_backup_extension)"

    printf "Back up conflicting files with Home Manager's -b option? [Y/n] "
    read -r reply

    case "$reply" in
      ""|[Yy]|[Yy][Ee][Ss])
        backup_mode="enabled"
        ;;
      [Nn]|[Nn][Oo])
        backup_mode="disabled"
        backup_extension=""
        ;;
      *)
        echo "error: expected yes or no" >&2
        exit 2
        ;;
    esac
  else
    backup_mode="disabled"
  fi
fi

if [[ "$backup_mode" == "enabled" ]]; then
  if [[ -z "$backup_extension" ]]; then
    backup_extension="$(timestamped_backup_extension)"
  fi

  validate_backup_extension "$backup_extension"
  home_manager_args+=(-b "$backup_extension")
  echo "info: Home Manager will back up conflicting files using extension: $backup_extension"
fi

echo "info: switching Home Manager configuration: $target"
nix run github:nix-community/home-manager/release-25.11 -- "${home_manager_args[@]}"

cat <<EOF

done.

Next (optional):
  ./scripts/set-default-shell.sh
EOF
