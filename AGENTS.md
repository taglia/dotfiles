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

## Stable channel currency

Every weekly update review must also say whether the flake is behind on the
NixOS stable release. The four stable inputs in `flake.nix` are pinned to a
release branch by name (`nixpkgs/nixos-<YY.MM>`,
`home-manager/release-<YY.MM>`, `nix-darwin/nix-darwin-<YY.MM>`,
`nixvim/nixos-<YY.MM>`), so a new release never arrives through
`nix flake update`; it has to be a deliberate edit. Check, with `gh api`:

- whether `NixOS/nixpkgs` has a `release-<next>` / `nixos-<next>` branch
  (`<next>` is the following May or November, e.g. 26.05 → 26.11 → 27.05), and
  whether `https://channels.nixos.org/nixos-<next>` redirects (`/usr/bin/curl -I`)
  instead of returning 404;
- the "NixOS <next> – Release schedule" issue in nixpkgs for the branch-off
  and release dates (search `repo:NixOS/nixpkgs is:issue "<next>" release in:title`);
- whether `nix-community/home-manager` (`release-<next>`),
  `nix-darwin/nix-darwin` (`nix-darwin-<next>`) and `nix-community/nixvim`
  (`nixos-<next>`) have their matching branches yet.

Report one of: not branched yet (give the scheduled dates), beta channel out
but some inputs lack a branch (name them), or released with all four branches
available. In the last case propose the channel bump as its own commit,
separate from the weekly lock update, and remind that the old release is
supported for about one month after the new one ships. Do not bump the
channel inside a weekly update without the user's go-ahead.

## Pending upstream checks

- **Git 2.54.1 built locally** (`lib/patched-git.nix`, used by
  `programs.git.package` in `modules/home/dev.nix` and by
  `environment.systemPackages` in `modules/nixos/base.nix`): nixos-26.05 ships
  Git 2.54.0, which is missing the 2026-11-10 security release (six CVEs;
  CVE-2026-111760 is code execution on a recursive clone of a malicious
  repository). The bump ([PR 586429](https://github.com/NixOS/nixpkgs/pull/586429))
  sits in `staging-26.05` with no `staging-next-26.05` iteration open, and
  unstable's 2.56.0 is affected too (2.56.1 is on `staging-next`). The override
  disables itself once `nix eval --inputs-from . nixpkgs#git.version` is
  >= 2.54.1; when it is, delete `lib/patched-git.nix` and its two callers. It
  covers only the `git` on PATH: packages that depend on Git (the `nix fmt`
  wrapper, Neovim plugins, fetchers) keep the channel's build.
- **Pi's Node.js pinned to stable for 24.22.3** (`profiles/ai.nix` `piNodejs`,
  consumed by `modules/home/pi.nix`): the 2026-11-10 Node security release
  (16 CVEs, 7 high, all in the HTTP/2, HTTPS and TLS _server_ code paths)
  reached nixos-26.05 on 2026-11-20, while nixos-unstable is still on 24.22.2
  (its bump, PR 586806, is on `staging`). `piNodejs` therefore selects stable
  `pkgs.nodejs` for Pi, `pi-npm` and the Node in `home.packages`, and Pi is
  built locally against it. The pin turns itself off once
  `nix eval --inputs-from . nixpkgs-unstable#nodejs.version` is >= 24.22.3;
  when it is, reduce `piNodejs` back to plain `pkgs-unstable.nodejs` and drop
  this entry.
- **markdown-table-wrap.nvim is a stopgap** (`modules/home/vim/plugins/misc.nix`):
  it wraps cells of markdown tables wider than the window because
  render-markdown.nvim cannot reflow them. If render-markdown gains native
  cell-wrapping for wide tables (tracked in
  [MeanderingProgrammer/render-markdown.nvim#616](https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/616),
  PR #617), remove the `markdown-table-wrap` plugin, its `extraPlugins` /
  `extraConfigLua` setup, and re-enable `plugins.render-markdown.settings.pipe_table`
  with the new wrapping option.
