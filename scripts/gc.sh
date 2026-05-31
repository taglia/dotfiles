#!/usr/bin/env bash
set -euo pipefail

older_than="30d"
dry_run=0
run_nix=1
run_brew=1
sudo_mode="auto"
brew_prune=""

usage() {
  cat <<'EOF'
Usage: gc.sh [options]

Clean old Nix generations and unreachable store paths, plus Homebrew
orphans/caches on macOS.

Options:
  --older-than PERIOD  Keep Nix generations newer than PERIOD (default: 30d)
  --dry-run            Show what would be removed where supported
  --no-nix             Skip Nix garbage collection
  --no-brew            Skip Homebrew cleanup
  --sudo               Also run Nix garbage collection through sudo
  --no-sudo            Do not run sudo Nix garbage collection
  --prune DAYS|all     Pass --prune to brew cleanup
  -h, --help           Show this help

Examples:
  scripts/gc.sh
  scripts/gc.sh --dry-run
  scripts/gc.sh --older-than 14d --no-brew
  scripts/gc.sh --sudo --prune all
EOF
}

log() {
  printf '%s\n' "$*"
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

run_cmd() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
  "$@"
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

is_system_nix_host() {
  [[ -e /etc/NIXOS ]] && return 0

  if [[ "$(uname -s)" == "Darwin" ]]; then
    has_command darwin-rebuild && return 0
    [[ -x /run/current-system/sw/bin/darwin-rebuild ]] && return 0
  fi

  return 1
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --older-than)
      [[ "$#" -ge 2 ]] || die "--older-than requires a period, such as 30d"
      older_than="$2"
      shift 2
      ;;
    --older-than=*)
      older_than="${1#*=}"
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --no-nix)
      run_nix=0
      shift
      ;;
    --no-brew)
      run_brew=0
      shift
      ;;
    --sudo)
      sudo_mode="always"
      shift
      ;;
    --no-sudo)
      sudo_mode="never"
      shift
      ;;
    --prune)
      [[ "$#" -ge 2 ]] || die "--prune requires DAYS or all"
      brew_prune="$2"
      shift 2
      ;;
    --prune=*)
      brew_prune="${1#*=}"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

if [[ -z "$older_than" ]]; then
  die "--older-than cannot be empty"
fi

if [[ "$run_nix" -eq 1 ]]; then
  has_command nix-collect-garbage || die "nix-collect-garbage not found on PATH"

  nix_gc_args=(nix-collect-garbage --delete-older-than "$older_than")
  if [[ "$dry_run" -eq 1 ]]; then
    nix_gc_args+=(--dry-run)
  fi

  log "Running user Nix garbage collection for generations older than ${older_than}."
  run_cmd "${nix_gc_args[@]}"

  run_sudo_nix=0
  case "$sudo_mode" in
    always)
      run_sudo_nix=1
      ;;
    never)
      run_sudo_nix=0
      ;;
    auto)
      if [[ "${EUID:-$(id -u)}" -ne 0 ]] && has_command sudo && is_system_nix_host; then
        run_sudo_nix=1
      fi
      ;;
  esac

  if [[ "$run_sudo_nix" -eq 1 ]]; then
    has_command sudo || die "sudo was requested but is not on PATH"
    log "Running system/root Nix garbage collection for generations older than ${older_than}."
    run_cmd sudo "${nix_gc_args[@]}"
  elif [[ "$sudo_mode" == "auto" ]]; then
    log "Skipping sudo Nix garbage collection; no NixOS/nix-darwin system profile was detected."
  fi
else
  log "Skipping Nix garbage collection."
fi

if [[ "$run_brew" -eq 1 ]]; then
  if [[ "$(uname -s)" != "Darwin" ]]; then
    log "Skipping Homebrew cleanup; this is not macOS."
  elif ! has_command brew; then
    warn "brew not found on PATH; skipping Homebrew cleanup"
  else
    brew_autoremove_args=(brew autoremove)
    brew_cleanup_args=(brew cleanup)

    if [[ "$dry_run" -eq 1 ]]; then
      brew_autoremove_args+=(--dry-run)
      brew_cleanup_args+=(--dry-run)
    fi

    if [[ -n "$brew_prune" ]]; then
      brew_cleanup_args+=(--prune="$brew_prune")
    fi

    log "Running Homebrew autoremove for orphaned dependencies."
    run_cmd "${brew_autoremove_args[@]}"

    log "Running Homebrew cleanup for stale downloads and old formula versions."
    run_cmd "${brew_cleanup_args[@]}"
  fi
else
  log "Skipping Homebrew cleanup."
fi
