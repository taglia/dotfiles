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

## Network access from the agent shell

Use Apple's `/usr/bin/curl` (and `gh api`, which is authenticated) for the
weekly update checks and any other outbound request. Little Snitch keys its
rules on code identity; the Nix-built `curl` on PATH and mise's `python3` are
ad-hoc signed with no Team ID, so Little Snitch falls back to the store path
and every update that changes that path turns them into a new, unapproved
program whose connections hang until the user clicks Allow (observed
2026-11-14). Apple's curl is Apple-signed with a stable identity, so one allow
rule survives Nix updates. Do not fetch with Python's `urllib`; shell out to
`/usr/bin/curl` and parse the result instead. A hang or HTTP 000 means a
pending Little Snitch prompt, not a policy block: tell the user and retry once
they have approved it.

## Pending upstream checks

- **Node.js 24.22.3 (November 2026 security release) not in either channel**
  (`profiles/ai.nix` `piNodejs`, consumed by `modules/home/pi.nix`): Pi,
  `pi-npm` and the Node in `home.packages` run `pkgs-unstable.nodejs`
  (24.22.2). The 2026-11-11 release fixes 16 CVEs (7 high, all in the
  HTTP/2, HTTPS and TLS _server_ code paths); nixpkgs has it only on
  `staging-next-26.05` / `staging` (PRs 586812, 586806), not on master or any
  channel, so there is nothing to pin to yet. Each weekly update, check
  `nix eval --inputs-from . nixpkgs-unstable#nodejs.version` and
  `...#nodejs.version` (stable); prefer whichever channel reaches >= 24.22.3
  first and repoint `piNodejs` if that is stable. mise already pins
  `node = "24.22.3"` in `files/mise/config.toml` (installs from nodejs.org)
  with a `minimum_release_age_excludes = ["node"]` exception, because the
  10-day gate hides 24.22.3 until 2026-11-21 even for an exact pin; after that
  date relax the pin to `"24"` and drop the exception.
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
