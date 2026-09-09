#!/usr/bin/env bash
# Invoked through the pinned Node/TypeScript Nix shell by CI and pre-commit.
set -euo pipefail
cd "$(dirname "$0")/.."

# Nix, not Bash, expands the system interpolation in this expression.
# shellcheck disable=SC2016
pi_package=$(nix build --impure --no-link --print-out-paths --expr '
  let f = builtins.getFlake (toString ./.);
      pkgs = f.inputs.nixpkgs-unstable.legacyPackages.${builtins.currentSystem};
  in pkgs.pi-coding-agent')
sdk="$pi_package/lib/node_modules/pi-monorepo"

# Typecheck against the actual pinned SDK without npm installs or leaving
# node_modules in the repo. Node typings are already bundled by Pi.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -R files/pi/agent/extensions/agent-async "$tmp/src"
cp -R files/pi/agent/extensions/answer-section "$tmp/answer-section"
mkdir -p "$tmp/node_modules/@earendil-works"
ln -s "$sdk" "$tmp/node_modules/@earendil-works/pi-coding-agent"
for name in pi-ai pi-agent-core pi-tui; do
  ln -s "$sdk/node_modules/@earendil-works/$name" "$tmp/node_modules/@earendil-works/$name"
done
ln -s "$sdk/node_modules/typebox" "$tmp/node_modules/typebox"
ln -s "$sdk/node_modules/@types" "$tmp/node_modules/@types"
(
  cd "$tmp"
  tsc --noEmit --module nodenext --moduleResolution nodenext --target es2023 \
    --allowImportingTsExtensions --strict --skipLibCheck --types node \
    src/*.ts src/tests/*.ts src/tests/fixtures/*.ts \
    answer-section/*.ts answer-section/tests/*.ts
)

PI_AGENT_TEST_SDK="$sdk" node --test \
  files/pi/agent/extensions/agent-async/tests/*.test.ts \
  files/pi/agent/extensions/answer-section/tests/*.test.ts
