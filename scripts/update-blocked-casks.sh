#!/usr/bin/env bash
# Upgrade casks whose vendor background updater is deliberately blocked
# (e.g. Google Chrome without its Keystone agent): Homebrew greedy upgrades
# are the ONLY update channel these apps have left. `brew upgrade --greedy`
# installs the catalog version even when the installed one is newer (after a
# manual update, or while Homebrew's catalog lags the vendor), so each cask's
# drift direction is checked first and ahead-of-catalog installs are skipped
# instead of downgraded. Run as the Homebrew admin user; the cask list lives
# in the justfile (updater_blocked).
set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <cask>..." >&2
  exit 2
fi

for cask in "$@"; do
  info="$(brew info --cask --json=v2 "$cask")"
  installed="$(jq -r '.casks[0].installed // empty' <<<"$info")"
  catalog="$(jq -r '.casks[0].version' <<<"$info")"

  if [ -z "$installed" ]; then
    echo "$cask: not installed; skipping" >&2
    continue
  fi

  if [ "$installed" = "$catalog" ]; then
    echo "$cask: up to date ($installed)"
  elif [ "$(printf '%s\n%s\n' "$installed" "$catalog" | sort -V | tail -n1)" = "$installed" ]; then
    echo "$cask: installed $installed is ahead of catalog $catalog; skipping (a greedy upgrade would downgrade)"
  else
    brew upgrade --cask --greedy "$cask"
  fi
done
