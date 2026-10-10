#!/usr/bin/env bash
# Shared file selection for just check, CI, and the pre-commit hook.
# The caller supplies the linter through its Nix shell.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
linter="${1:?Usage: check-lint.sh shellcheck|deadnix|statix|stylua|prettier}"
case "$linter" in
  shellcheck) patterns=('scripts/**/*.sh' 'files/**/*.sh') ;;
  deadnix|statix) patterns=('**/*.nix') ;;
  stylua) patterns=('files/sketchybar/**/*.lua') ;;
  prettier) patterns=('files/**/*.ts') ;;
  *) echo "Unknown linter: $linter" >&2; exit 2 ;;
esac

# Git glob pathspecs include root-level files with **/. NUL delimiters preserve
# whitespace; deleted tracked paths are skipped. pipefail propagates Git errors.
pathspecs=()
for pattern in "${patterns[@]}"; do
  pathspecs+=(":(glob)$pattern")
done
git ls-files --cached --others --exclude-standard -z -- "${pathspecs[@]}" | {
  files=()
  while IFS= read -r -d '' file; do
    if [ -f "$file" ]; then
      files+=("./$file")
    fi
  done
  if [ "${#files[@]}" -eq 0 ]; then
    exit 0
  fi

  case "$linter" in
    shellcheck) shellcheck "${files[@]}" ;;
    deadnix) deadnix --fail "${files[@]}" ;;
    statix)
      # Statix accepts only one target per invocation. Report all failures.
      status=0
      for file in "${files[@]}"; do
        statix check "$file" || status=1
      done
      exit "$status"
      ;;
    stylua) stylua --check "${files[@]}" ;;
    prettier) prettier --check "${files[@]}" ;;
  esac
}
