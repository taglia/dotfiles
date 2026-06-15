#!/usr/bin/env bash
# Emit a single Nerdfont OS icon for the tmux status bar.
case "$(uname -s)" in
  Darwin) printf '%s' '' ;;
  Linux)
    if [[ -f /etc/os-release ]]; then
      # shellcheck source=/dev/null
      source /etc/os-release
      case "$ID" in
        arch) printf '%s' '' ;;
        debian) printf '%s' '' ;;
        ubuntu) printf '%s' '' ;;
        nixos) printf '%s' '' ;;
        *) printf '%s' '' ;;
      esac
    else
      printf '%s' ''
    fi
    ;;
  *) printf '%s' '' ;;
esac
