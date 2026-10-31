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

- **Stable Node pinned for Pi** (`profiles/ai.nix` `piNodejs`, consumed by
  `modules/home/pi.nix`): Pi, `pi-npm` and the Node in `home.packages` use
  stable `pkgs.nodejs` (24.22.1, Brotli 1.2.1) because nixos-unstable still
  ships Node 24.21.0 with Brotli 1.2.0 (October 2026 Node security release and
  CVE-2026-111497 unfixed). Each weekly update, check
  `nix eval --inputs-from . nixpkgs-unstable#nodejs.version` and
  `...#brotli.version`; once unstable has Node >= 24.22.1 with Brotli >= 1.2.1,
  set `piNodejs = pkgs-unstable.nodejs` and drop the `pi-coding-agent`
  override. Also relax `node = "24.22.1"` in `files/mise/config.toml` to `"24"`
  once mise's fuzzy resolution picks a patched release on its own.
- **OpenCode built with Bun 1.4.4** (`profiles/ai.nix` `bun-fixed`): Bun < 1.4.4
  embeds the vulnerable Brotli. Remove `bun-fixed` and go back to plain
  `pkgs-unstable.opencode` once `nix eval --inputs-from . nixpkgs-unstable#bun.version`
  is >= 1.4.4 (bump tracked in
  [NixOS/nixpkgs#574334](https://github.com/NixOS/nixpkgs/pull/574334)).
- **marksman on the binary .NET runtime** (`modules/home/vim/plugins/lsp/lsp.nix`):
  the stable lock's source-built `dotnetCorePackages.runtime_9_0` (9.0.22) is
  not in the binary cache for aarch64-darwin, which made marksman rebuild the
  whole .NET SDK locally (hours). Its `package` swaps in `runtime_9_0-bin`.
  Remove the override once
  `nix build --inputs-from . nixpkgs#dotnetCorePackages.runtime_9_0` substitutes
  on aarch64-darwin again.
- **bicep protoc override on Darwin** (`modules/home/vim/plugins/lsp/conform.nix`):
  stable's bicep fails to build on aarch64-darwin (Grpc.Tools ships x86_64-only
  protoc; [NixOS/nixpkgs#565350](https://github.com/NixOS/nixpkgs/issues/565350),
  fix in [PR 579953](https://github.com/NixOS/nixpkgs/pull/579953)) and is not
  in the binary cache. Remove the `overrideAttrs` once
  `nix build --inputs-from . nixpkgs#bicep` succeeds or substitutes on
  aarch64-darwin without it.
- **markdown-table-wrap.nvim is a stopgap** (`modules/home/vim/plugins/misc.nix`):
  it wraps cells of markdown tables wider than the window because
  render-markdown.nvim cannot reflow them. If render-markdown gains native
  cell-wrapping for wide tables (tracked in
  [MeanderingProgrammer/render-markdown.nvim#616](https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/616),
  PR #617), remove the `markdown-table-wrap` plugin, its `extraPlugins` /
  `extraConfigLua` setup, and re-enable `plugins.render-markdown.settings.pipe_table`
  with the new wrapping option.
