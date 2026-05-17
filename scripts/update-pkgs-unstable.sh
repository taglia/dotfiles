#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ ! -f "flake.nix" ]]; then
  echo "error: expected to run from a Nix flake repo (missing flake.nix)" >&2
  exit 1
fi

nix flake update nixpkgs-unstable
