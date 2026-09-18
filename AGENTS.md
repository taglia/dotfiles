# Notes for agents

## Before committing

CI (`.github/workflows/check.yml`) enforces nixfmt, shellcheck, deadnix,
statix, stylua, and prettier, plus flake eval for all systems. Run the
relevant checks locally before every commit — an unformatted file once kept
CI red for nine consecutive pushes:

- `nix fmt -- --check` (or plain `nix fmt` to fix) for any `*.nix` change
- `nix shell --inputs-from . nixpkgs#deadnix --command deadnix --fail .`
- `nix shell --inputs-from . nixpkgs-unstable#statix --command statix check .`
- `nix shell --inputs-from . nixpkgs#stylua --command stylua --check files/sketchybar` for Lua
- `nix shell --inputs-from . nixpkgs#prettier --command prettier --check "files/**/*.ts"` for TypeScript
- shellcheck for `*.sh` under `scripts/` and `files/`
- `nix shell --inputs-from . nixpkgs-unstable#nodejs nixpkgs#typescript --command bash scripts/check-agent-async.sh`
  for `agent-async`, `answer-section`, or `flake.lock` changes (typecheck,
  DAG/lifecycle and display-entry tests, and local mock providers; no paid API calls)

The pre-commit hook (`.githooks/pre-commit`, wired up by
`scripts/bootstrap_and_switch.sh` via `core.hooksPath`) mirrors these and
blocks the commit on failure — don't bypass it with `--no-verify`; fix the
finding instead. When editing the checks, keep the hook and `check.yml` in
sync.

## Pending upstream checks

- **markdown-table-wrap.nvim is a stopgap** (`modules/home/vim/plugins/misc.nix`):
  it wraps cells of markdown tables wider than the window because
  render-markdown.nvim cannot reflow them. If render-markdown gains native
  cell-wrapping for wide tables (tracked in
  [MeanderingProgrammer/render-markdown.nvim#616](https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/616),
  PR #617), remove the `markdown-table-wrap` plugin, its `extraPlugins` /
  `extraConfigLua` setup, and re-enable `plugins.render-markdown.settings.pipe_table`
  with the new wrapping option.
