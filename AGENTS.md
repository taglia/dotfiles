# Notes for agents

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
