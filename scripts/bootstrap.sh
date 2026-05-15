#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ ! -f "flake.nix" ]]; then
  echo "error: expected to run from a Nix flake repo (missing flake.nix)" >&2
  exit 1
fi

target=""

usage() {
  cat <<'EOF'
Usage: ./scripts/bootstrap.sh [--target <name>]

Runs Home Manager from a flake in this repo.

--target  Home Manager configuration name from flake.nix (homeConfigurations.*)
          If omitted, auto-detects based on OS + arch.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      target="${2:-}"
      shift 2
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
  local desired="experimental-features = nix-command flakes"

  if [[ -f /etc/nix/nix.conf ]] || [[ -d /etc/nix ]]; then
    if [[ ! -f /etc/nix/nix.conf ]]; then
      echo "info: creating /etc/nix/nix.conf (requires sudo)"
      sudo mkdir -p /etc/nix
      echo "$desired" | sudo tee /etc/nix/nix.conf >/dev/null
      return 0
    fi

    if ! sudo grep -qE '^\s*experimental-features\s*=.*\bflakes\b' /etc/nix/nix.conf; then
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

  if ! grep -qE '^\s*experimental-features\s*=.*\bflakes\b' "$HOME/.config/nix/nix.conf"; then
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

echo "info: switching Home Manager configuration: $target"
nix run github:nix-community/home-manager/release-25.11 -- switch --flake ".#${target}"

cat <<EOF

done.

Next (optional):
  ./scripts/set-default-shell.sh
EOF

