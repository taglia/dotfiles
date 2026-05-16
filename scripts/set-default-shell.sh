#!/usr/bin/env bash
set -euo pipefail

target_user="$(id -un)"

if [[ "$target_user" == "root" ]]; then
  cat >&2 <<'EOF'
error: do not run this script with sudo.

Run it as the account whose login shell should change; the script will ask for sudo only when it needs to update /etc/shells.
EOF
  exit 1
fi

shell_path="${1:-}"
if [[ -z "$shell_path" ]]; then
  if command -v fish >/dev/null 2>&1; then
    shell_path="$(command -v fish)"
  else
    echo "error: fish not found on PATH; run home-manager switch first (or pass a shell path)" >&2
    exit 1
  fi
fi

if [[ ! -x "$shell_path" ]]; then
  echo "error: not an executable file: $shell_path" >&2
  exit 1
fi

if [[ ! -f /etc/shells ]]; then
  echo "error: /etc/shells not found on this system" >&2
  exit 1
fi

if ! grep -qxF "$shell_path" /etc/shells; then
  echo "info: adding $shell_path to /etc/shells (requires sudo)"
  echo "$shell_path" | sudo tee -a /etc/shells >/dev/null
fi

echo "info: changing login shell for $target_user to $shell_path"
chsh -s "$shell_path"

echo "done. Log out/in (or restart your terminal) to fully apply."
