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
username=""
github_username=""
email=""
bootstrap_flake_dir="$repo_root"

usage() {
  cat <<'EOF'
Usage: ./scripts/bootstrap_and_switch.sh [--target <name>] [--username <name>] [--github-username <name>] [--email <address>] [--backup[ <extension>] | --backup-extension <extension> | --no-backup]

Updates the user identity in flake.nix, then runs standalone Home Manager from this repo.
This script does not run nix-darwin. On macOS with nix-darwin, prefer:
  darwin-rebuild switch --flake .#mbp

--target  Home Manager configuration name from flake.nix (homeConfigurations.*)
          If omitted, prompts interactively and defaults to mbp-home.
--username <name>
          Local account username to use for home.username and home.homeDirectory.
--github-username <name>
          GitHub username to use for programs.git.settings.user.name.
--email <address>
          Email address to use for programs.git.settings.user.email.
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

validate_nix_string_value() {
  local name="$1"
  local value="$2"

  if [[ -z "$value" ]]; then
    echo "error: $name cannot be empty" >&2
    exit 2
  fi

  if [[ "$value" == *$'\n'* || "$value" == *$'\r'* || "$value" == *'"'* || "$value" == *"\\"* ]]; then
    echo "error: $name must not contain newlines, double quotes, or backslashes" >&2
    exit 2
  fi
}

prompt_identity_value() {
  local prompt="$1"
  local default_value="$2"
  local value

  if [[ -n "$default_value" ]]; then
    printf "%s [%s]: " "$prompt" "$default_value" >&2
  else
    printf "%s: " "$prompt" >&2
  fi

  read -r value
  if [[ -z "$value" ]]; then
    value="$default_value"
  fi

  printf "%s" "$value"
}

current_flake_user_value() {
  local attr="$1"
  perl -0ne 'print "$1\n" if /'"$attr"'\s*=\s*"([^"]*)"/' flake.nix | head -n 1
}

configure_target() {
  local default_target="mbp-home"

  if [[ -n "$target" ]]; then
    return 0
  fi

  if [[ -t 0 && -t 1 ]]; then
    target="$(prompt_identity_value "Home Manager profile" "$default_target")"
  else
    target="$default_target"
  fi

  if [[ -z "$target" ]]; then
    echo "error: target cannot be empty" >&2
    exit 2
  fi
}

configure_identity() {
  local default_username default_github_username default_email

  default_username="$(current_flake_user_value "username")"
  default_github_username="$(current_flake_user_value "githubUsername")"
  default_email="$(current_flake_user_value "email")"

  if [[ -z "$default_username" ]]; then
    default_username="$(id -un)"
  fi

  if [[ -z "$default_github_username" ]]; then
    default_github_username="$default_username"
  fi

  if [[ -z "$default_email" ]]; then
    default_email="${default_github_username}@example.com"
  fi

  if [[ -z "$username" || -z "$github_username" || -z "$email" ]]; then
    if [[ ! -t 0 || ! -t 1 ]]; then
      cat >&2 <<'EOF'
error: bootstrap needs identity values before installing.

Pass --username, --github-username, and --email when running non-interactively.
EOF
      exit 2
    fi

    echo "info: configuring local identity before Home Manager activation"

    if [[ -z "$username" ]]; then
      username="$(prompt_identity_value "Local username" "$default_username")"
    fi

    if [[ -z "$github_username" ]]; then
      github_username="$(prompt_identity_value "GitHub username" "$default_github_username")"
    fi

    if [[ -z "$email" ]]; then
      email="$(prompt_identity_value "Git email" "$default_email")"
    fi
  fi

  validate_nix_string_value "username" "$username"
  validate_nix_string_value "github username" "$github_username"
  validate_nix_string_value "email" "$email"

  DOTFILES_BOOTSTRAP_USERNAME="$username" \
  DOTFILES_BOOTSTRAP_GITHUB_USERNAME="$github_username" \
  DOTFILES_BOOTSTRAP_EMAIL="$email" \
    perl -0pi -e '
      my $username = $ENV{"DOTFILES_BOOTSTRAP_USERNAME"};
      my $github_username = $ENV{"DOTFILES_BOOTSTRAP_GITHUB_USERNAME"};
      my $email = $ENV{"DOTFILES_BOOTSTRAP_EMAIL"};

      s/(user\s*=\s*\{\s*username\s*=\s*")[^"]*(";\s*githubUsername\s*=\s*")[^"]*(";\s*email\s*=\s*")[^"]*(";\s*\};)/$1$username$2$github_username$3$email$4/s
        or die "could not update user identity in flake.nix\n";
    ' flake.nix

  echo "info: updated flake.nix identity for $username"
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
    --username)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "error: --username requires a value" >&2
        usage >&2
        exit 2
      fi
      username="${2:-}"
      shift 2
      ;;
    --github-username)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "error: --github-username requires a value" >&2
        usage >&2
        exit 2
      fi
      github_username="${2:-}"
      shift 2
      ;;
    --email)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "error: --email requires a value" >&2
        usage >&2
        exit 2
      fi
      email="${2:-}"
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
      echo "info: /etc/nix exists but /etc/nix/nix.conf is missing."
      echo "info: sudo is needed to create /etc/nix/nix.conf and enable Nix flakes."
      sudo mkdir -p /etc/nix
      echo "$desired" | sudo tee /etc/nix/nix.conf >/dev/null
      return 0
    fi

    if [[ -r /etc/nix/nix.conf ]]; then
      if has_required_features /etc/nix/nix.conf; then
        has_features=0
      else
        has_features=1
      fi
    else
      echo "info: sudo is needed to read /etc/nix/nix.conf and check whether flakes are enabled."
      if sudo bash -c "$(declare -f has_required_features); has_required_features /etc/nix/nix.conf"; then
        has_features=0
      else
        has_features=1
      fi
    fi

    if [[ "$has_features" -ne 0 ]]; then
      echo "info: sudo is needed to update /etc/nix/nix.conf and enable Nix flakes."
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

configure_target
configure_identity
ensure_flakes_enabled

home_manager_args=(switch --flake "${bootstrap_flake_dir}#${target}")

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
nix run github:nix-community/home-manager/release-26.05 -- "${home_manager_args[@]}"

cat <<EOF

done.

Next (optional):
  ./scripts/set-default-shell.sh  # standalone Home Manager only
EOF
