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

The pre-commit hook (`.githooks/pre-commit`, wired up by
`scripts/bootstrap_and_switch.sh` via `core.hooksPath`) mirrors these and
blocks the commit on failure — don't bypass it with `--no-verify`; fix the
finding instead. When editing the checks, keep the hook and `check.yml` in
sync.

## Pending upstream checks

- **nono `doCheck = false` override is a stopgap** (`profiles/ai.nix`): nono's
  test suite is environment-sensitive (it tests sandboxing) and nixpkgs' skip
  list only matches Hydra's sandboxed NixOS builders — on darwin one extra
  test fails (`why_self_reports_active_profile_deny_before_covering_allow`,
  build `$HOME` under `/nix`), on the Debian dev box ~44 others fail. So the
  override disables the check phase entirely. It changes the derivation hash,
  so nono can no longer be substituted from cache.nixos.org and every machine
  compiles it from source. At session start, check whether
  [NixOS/nixpkgs#558782](https://github.com/NixOS/nixpkgs/pull/558782) (adds
  the same skip upstream, resolving issue #558647) has merged and reached the
  pinned nixpkgs-unstable revision; once it has, remind the user to drop the
  override so binary-cache substitution works again.

- **markdown-table-wrap.nvim is a stopgap** (`modules/home/vim/plugins/misc.nix`):
  it wraps cells of markdown tables wider than the window because
  render-markdown.nvim cannot reflow them. If render-markdown gains native
  cell-wrapping for wide tables (tracked in
  [MeanderingProgrammer/render-markdown.nvim#616](https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/616),
  PR #617), remove the `markdown-table-wrap` plugin, its `extraPlugins` /
  `extraConfigLua` setup, and re-enable `plugins.render-markdown.settings.pipe_table`
  with the new wrapping option.
