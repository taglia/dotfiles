# dotfiles (Nix + Home Manager + nix-darwin)

This repo is a Nix flake that defines Home Manager configurations for Linux and macOS, plus a nix-darwin configuration for macOS system-level setup.

> **Status: personal configuration, not a maintained project.** This repo is
> public for my own convenience — it is my live machine configuration, shaped
> by my hardware, accounts, and habits, and it changes whenever mine do.
> Everyone is welcome to clone it, fork it, and reuse whatever is useful
> (`identity.nix` exists to swap in your own identity), but it is not a
> maintained FOSS package: no support, no compatibility promises, no issue
> triage. Use at your own risk — you are on your own. See [LICENSE](LICENSE)
> (MIT).

## Prerequisites

- Nix installed
  - Recommended (macOS + Linux): the official multi-user Nix installer. This
    flake lets nix-darwin manage `nix` (channels, registry, GC), which assumes
    the official daemon-based install.
  - Determinate Systems / Lix: also fine, but Determinate manages `nix.conf` and
    the daemon itself. If you use it, set `nix.enable = false` in the nix-darwin
    config so the two do not fight over `/etc/nix/nix.conf`.
- Build tools
  - macOS: install Xcode Command Line Tools: `xcode-select --install`
  - Linux: install your distro's build essentials (e.g. `build-essential`, `gcc`, `make`, etc.)

## 1) Install Nix

Official multi-user installer:

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

Then restart your terminal (or source the profile snippet the installer prints).

## 2) Enable flakes + nix-command

You need `nix-command` and `flakes` enabled. The simplest approach is to add this line to your Nix config:

```conf
experimental-features = nix-command flakes
```

Common locations:

- Multi-user Nix (typical on macOS + many Linux installs): `/etc/nix/nix.conf`
- Single-user Nix: `~/.config/nix/nix.conf`

After editing `/etc/nix/nix.conf`, restart the Nix daemon:

- macOS:
  - `sudo launchctl kickstart -k system/org.nixos.nix-daemon`
- Linux (systemd):
  - `sudo systemctl restart nix-daemon || true`

On macOS, nix-darwin also declares these settings once activated, but the initial bootstrap still needs flakes enabled before the first switch.

## 3) Clone the repo

```bash
git clone <this-repo-url> ~/dotfiles
cd ~/dotfiles
git config core.hooksPath .githooks
```

The last line enables the repo hooks (`.githooks/pre-commit` blocks committing the machine-local `identity.nix`). `core.hooksPath` is a local-only git setting, so it must be set per clone; `scripts/bootstrap_and_switch.sh` does this automatically, but the nix-darwin path does not.

## 4) Pick a target

Targets are defined in `lib/hosts.nix` (the `hosts` table) and exposed by `flake.nix` under `homeConfigurations`:

- `mbp` (also aliased as `mbp-home`)
- `mbp-admin` (the separate macOS admin account, local user `richie`: the dev
  setup without private secrets or the mbp-only extras; switch it while logged
  in as that user)
- `linux`
- `linux-ai`
- `linux-private`
- `linux-minimal`
- `linux-aws` (uses local user `admin`)
- `linux-openclaw` (uses local user `openclaw`)
- `linux-arm`
- `linux-minimal-arm`

There are also two NixOS hosts:

- `utm-vm` (`nixosConfigurations.utm-vm`): an aarch64-linux UTM virtual
  machine, switched with `just switch-utm-vm`.
- `ec2-x86-vm` (`nixosConfigurations.ec2-x86-vm`): an x86_64-linux AWS EC2
  instance built on the NixOS Amazon image, set up as a dev + AI workstation
  without the private agenix profile; switched on the instance itself with
  `just switch-ec2-x86-vm`.

Each target always includes the base profile. The Linux or macOS profile is selected from the target system in `lib/hosts.nix`, and the `ai` / `private` suffixes add those extra profile layers.

If you're not sure, start with:

- MacBook Pro, nix-darwin: `darwinConfigurations.mbp`
- MacBook Pro, standalone Home Manager only: `mbp-home`
- x86_64 Linux: `linux`
- aarch64 Linux: `linux-arm`

## 5) Apply the macOS system configuration (nix-darwin)

The main macOS path is `darwinConfigurations.mbp`. It wraps the same Home Manager modules and adds system-level pieces such as shell registration, sudo Touch ID support, macOS settings, native Nix packages, and Homebrew/Mac App Store inventory.

Build it without switching first:

```bash
nix build .#darwinConfigurations.mbp.system
```

Then switch when ready. On a fresh machine `darwin-rebuild` is not on `PATH` yet (it only appears after the first activation), so run it from the flake's nix-darwin input the first time (nix-darwin 26.05 requires `sudo`):

```bash
sudo nix run nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake .#mbp
```

After that first activation, subsequent switches are simply:

```bash
sudo darwin-rebuild switch --flake .#mbp
```

`darwin-rebuild switch` also activates the integrated Home Manager configuration for `taglia`.

Homebrew and Mac App Store apps are declared in `modules/darwin/homebrew.nix`. Current activation behavior is intentionally declarative:

- declared brews, casks, and MAS apps are installed if missing
- `nix-homebrew` pins the Homebrew client and the third-party Rootshell tap in `flake.lock`; taps are immutable and trust is limited to the Rootshell cask
- official formulae and casks continue to use Homebrew's signed JSON API rather than Nix-pinned `homebrew/core` / `homebrew/cask` taps
- Homebrew metadata is **not** auto-updated and formulae/casks are **not** upgraded during activation or ordinary manual commands; run `just update-brew` explicitly instead
- undeclared Homebrew and MAS apps can be removed, including related support files where Homebrew supports zapping, because `cleanup = "zap"` is enabled

Mac App Store apps require the Mac to be signed into an Apple ID that owns those apps. Keep `homebrew.masApps` complete when cleanup is enabled.

Routine update steps are in [`UPDATE-RUNBOOK.md`](UPDATE-RUNBOOK.md). Normal cask upgrades intentionally omit `--greedy` and `--force`; use the selective monthly recipe for a self-updating or unversioned cask that still needs Homebrew to update it.

Native Nix packages, fonts, and terminfo installed into the nix-darwin system profile live in `modules/darwin/packages.nix`. macOS system preferences are split by concern: Dock/Finder/Spaces in `modules/darwin/desktop.nix`, keyboard/trackpad/text input in `modules/darwin/input.nix`, and the remaining `system.defaults.*` (power, login window, control center, per-app defaults, environment) in `modules/darwin/system.nix`. AeroSpace and its native-tiling-disabling companion settings live in `modules/darwin/aerospace.nix`.

Docker Desktop is intentionally not managed. Container development on macOS uses Colima and Lima from Home Manager, with the Docker CLI and Docker Compose from nixpkgs. The VM backend package `qemu` is installed through nix-darwin because it is a host-level runtime dependency. Start the runtime manually when needed:

```bash
colima start
docker context ls
docker version
```

## 6) Apply a standalone Home Manager configuration

You can run Home Manager without installing it globally:

```bash
nix run github:nix-community/home-manager/release-26.05 -- switch --flake .#mbp-home
```

Replace `mbp-home` with the target you chose, e.g.:

```bash
nix run github:nix-community/home-manager/release-26.05 -- switch --flake .#linux
```

## 7) Shells

nix-darwin registers `bash`, `zsh`, and `fish` as valid shells and sets the primary user's login shell to the nix-darwin Fish path. Standalone Home Manager systems do not change the login shell automatically. If you are not using nix-darwin and want to make Fish your login shell:

1) Ensure Fish is installed (it should be after `home-manager switch`):

```bash
command -v fish
```

2) Add that path to `/etc/shells` if it is not already present (required by `chsh`):

```bash
fish_path="$(command -v fish)"
grep -qxF "$fish_path" /etc/shells || echo "$fish_path" | sudo tee -a /etc/shells
```

3) Change your login shell:

```bash
chsh -s "$(command -v fish)"
```

Log out and back in (or restart your terminal) to fully apply.

## Managed app config

Some application config is managed by Home Manager from files in this repo:

- Ghostty: `files/ghostty/config`
- OpenCode: `modules/home/opencode.nix` and `files/opencode/AGENTS.md` → `~/.config/opencode/`

AeroSpace is managed directly by nix-darwin through `services.aerospace`.

### Theming (Catppuccin Mocha)

`lib/catppuccin.nix` is the single source of truth for the Catppuccin Mocha palette. The themed configs that used to duplicate it are now generated from it: `files/starship.toml` (palette table) and the kitty theme via `modules/home/xdg-files.nix`, the fish colors via `modules/home/fish.nix`, and `colors.lua` (injected at build time) via `modules/home/sketchybar.nix`. tmux, Ghostty, and OpenCode use an upstream Catppuccin plugin or built-in theme and are intentionally not wired in. Change a color once in `lib/catppuccin.nix` to update every generated consumer.

### OpenCode security model

- OpenCode and its provider adapter come from the flake-pinned Nix package. Automatic updates, external plugins, external skills, LSP downloads, and project-local OpenCode configuration are disabled.
- Home Manager links the complete `~/.config/opencode` directory to the read-only Nix store. This also prevents OpenCode from implicitly installing `@opencode-ai/plugin` into that directory.
- The provider allowlist contains only Ollama Cloud. Its API key is read directly from the file named by `OLLAMA_API_KEY_FILE`; plaintext is not placed in the Nix store or exported to agent subprocesses.
- Built-in web search uses Exa and built-in web fetch connects directly to the requested URL. Both require tool approval and neither installs a local plugin or MCP server.
- Keep OpenCode sessions and other runtime state under `~/.local/share/opencode` unmanaged.

## Package release cooling-off policy

Home Manager installs a ten-day minimum release age for package managers that
support a rolling cutoff:

| Manager | Managed configuration | Policy value |
| --- | --- | --- |
| npm | `~/.npmrc` | `min-release-age=10` |
| pnpm | `~/.config/pnpm/config.yaml` | `minimumReleaseAge: 14400` minutes, strict and fail-closed on missing timestamps |
| Yarn 4.12+ | `~/.yarnrc.yml` | `npmMinimalAgeGate: "10d"` |
| Bun | `~/.config/.bunfig.toml` | `minimumReleaseAge = 864000` seconds |
| uv | `~/.config/uv/uv.toml` | `exclude-newer = "10 days"` |
| mise | `~/.config/mise/config.toml` | `minimum_release_age = "10d"` |

The policy applies when a package manager resolves a registry version. It does
not establish that an older package is trustworthy, replace lockfiles or hash
verification, or consistently cover Git dependencies, direct URLs and versions
whose source does not publish a usable timestamp. Existing installed versions
are not automatically changed.

For an urgent security fix, make the narrowest temporary exception supported
by that manager and remove it immediately afterwards. Examples include npm's
`--min-release-age-exclude=<package>`, Yarn's one-shot `--no-time-gate`, uv's
`--exclude-newer-package <package>=false`, or an exact mise version (exact
versions intentionally bypass mise's fuzzy-version cutoff). Avoid disabling
the global policy for every package.

Nix is handled differently: `flake.lock` remains the version and integrity
boundary, and temporary check tools use `nix shell --inputs-from .` so they
resolve from that same lock. There is no additional ten-day Nix cutoff.
Homebrew and Mac App Store updates also remain explicit and manual because
neither exposes a supported, reliable per-release age gate. In particular,
the Homebrew client and Rootshell tap are flake-pinned, while official package
metadata still comes from Homebrew's signed API. Casks with their own updater
can still update outside Homebrew.

The first switch upgrades the Home Manager-provided mise binary, but mise does
not automatically replace tools already installed in its mutable data
directory. On an existing machine, run this once after switching so the
currently old Node/npm and uv clients gain native cooldown support while the
new mise policy is active:

```bash
mise upgrade node uv
```

## Secrets

This repo uses `agenix` for encrypted secrets. Two files are the source of
truth: `secrets-machines.nix` declares the machines (recipient public keys +
private key locations), and `secrets.nix` declares the secrets - each entry
maps an encrypted payload under `secrets/` to the machines allowed to decrypt
it (`publicKeys`) and, optionally, an `envVarFile` environment variable for
the decrypted file path. Commit only encrypted `.age` files, `secrets.nix` and
`secrets-machines.nix`, never private SSH keys or plaintext secrets. (When
bootstrapping a fresh fork with no secrets yet, `secrets.nix` can simply be
`{ }` until the first secret is needed.)

This repo uses SSH keys as agenix identities. Prefer a machine-specific SSH key per machine; if available, use an `ed25519` key over RSA.

Check which public keys exist:

```bash
find ~/.ssh -maxdepth 1 -name '*.pub' -print | sort
```

Inspect the public key type before choosing one:

```bash
awk '{print $1, FILENAME}' ~/.ssh/*.pub
```

### Adding a machine

Machines are declared once in `secrets-machines.nix`:

```nix
mbp = {
  publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...";
  identity = "/Users/taglia/.ssh/id_ed25519";
};
```

`publicKey` is the age recipient referenced from `secrets.nix`; `identity` is the absolute path of the matching private key on that machine. The identity may live anywhere on the filesystem (including outside the user's home, e.g. a machine-level key), as long as it is readable by the user running Home Manager activation. Use machine-specific names such as `mbp`, `linux_workstation`, or `server_name`; avoid a generic personal name for machine recipients.

At activation, `profiles/private.nix` passes every declared identity to agenix, which silently skips the ones not present on the local machine - so each machine automatically decrypts with its own key, with no key paths hardcoded per profile. A key that exists on a machine but is not a recipient for a given secret is ignored without error (and never triggers a passphrase prompt, because age matches the recipient's public key before touching the private key). This activation-time behavior is distinct from the `agenix` CLI below, where you always pass an identity explicitly with `-i`.

### Adding a secret

1. Add one entry to `secrets.nix`:

   ```nix
   "secrets/example-api-token.age" = {
     publicKeys = [ mbp dev-vm ];
     envVarFile = "EXAMPLE_API_TOKEN_FILE";
   };
   ```

   `publicKeys` is where machine authorization lives: only a machine holding a
   matching private key can decrypt the payload. `envVarFile` is optional; see
   "Consuming a secret" below.

2. Encrypt the payload from the repo root using the matching private key:

   ```bash
   mkdir -p secrets
   agenix -e secrets/example-api-token.age -i ~/.ssh/id_ed25519
   ```

   The `-i` flag is a CLI-only detail: it tells `agenix` which private key to use for this manual encryption/decryption and accepts any path. It has no effect on which identities are used later at activation (those come from `secrets-machines.nix`, see "Adding a machine"). For an API token the editor buffer contains the raw token (or an env-file style `EXAMPLE_API_TOKEN=...` line if a service expects an env file); for a binary file, pipe it in instead of opening an editor:

   ```bash
   agenix -e secrets/example.age < ./example.bin
   ```

3. Rebuild (`darwin-rebuild switch --flake .#mbp` or `just switch-home mbp-home`).

No other edits are needed: `profiles/private.nix` imports `secrets.nix` and
derives `age.secrets` and `home.sessionVariables` automatically, wiring only
secrets whose `.age` payload exists in the checkout. age secret names are
derived from the file name, e.g. `secrets/example-api-token.age` becomes
`config.age.secrets.example_api_token`.

### Consuming a secret

The important rule is to pass the decrypted file *path* around, never the secret value. Do not use `builtins.readFile` on a decrypted secret or put the value directly in `home.sessionVariables`, because that would copy the secret into the Nix store or generated config files.

- With `envVarFile` set, activation creates a stable per-user symlink at
  `~/.local/share/agenix/<secret-name>` and exports that path (via
  `home.sessionVariables`, so it reaches bash, zsh and fish alike). Scripts
  read the token at runtime:

  ```bash
  token="$(cat "$EXAMPLE_API_TOKEN_FILE")"
  curl -H "Authorization: Bearer $token" https://api.example.com/me
  ```

- Without `envVarFile`, the secret is just decrypted to a file. Reference `config.age.secrets.<name>.path` from any Home Manager module, e.g. a `home.file` symlink where an app expects a fixed location, or a user service that expects environment variables (store the secret as an env file, `EXAMPLE_API_TOKEN=...`, and set `EnvironmentFile = config.age.secrets.example_api_env.path;`).

After activation, `agenix` keeps the decrypted backing files in an OS-specific
runtime directory, typically under `$XDG_RUNTIME_DIR/agenix.d/` on Linux.
Secrets with `envVarFile` use the stable symlinks above, so consumers do not
depend on `XDG_RUNTIME_DIR` being present in their shell. Do not point consumers
at `agenix.d`; it is the private generation directory, while
`config.age.secrets.<name>.path` is the stable consumer path.

### Rotating recipients

If recipient keys change, re-encrypt existing secrets (the agenix CLI reads the recipient lists from `secrets.nix`):

```bash
agenix -r -i ~/.ssh/id_ed25519
```

Trade-off to keep in mind: this repo standardizes on SSH keys as age identities (see above) because every machine already has one, but it does mean SSH access and secret decryption share the same credential lifecycle. Keep the keys machine-specific and not broadly reused; rotate the corresponding recipient in `secrets.nix` whenever a machine's key changes.

## Automation scripts

Common tasks are exposed through `just`:

```bash
just
just switch-darwin
just switch-home linux
just check
just check-brew-declared
just check-brew-updates
just check-brew-greedy
just gc --dry-run
```

`just switch-home` requires a target argument, e.g. `just switch-home mbp-home` or `just switch-home linux`. Update domains stay separate so `flake.lock` can be reviewed and checked before it changes the active Homebrew client or third-party tap. Use `just update-nix` for all flake inputs, `just update-unstable` for only `nixpkgs-unstable`, and `just update-brew` for routine Homebrew and Mac App Store updates. Follow [`UPDATE-RUNBOOK.md`](UPDATE-RUNBOOK.md) for the complete sequence.

`flake.lock` updates are intentionally manual (there is no automated dependency-update CI): run `just update-nix` (or `just update-unstable` for the unstable input) and review the diff before switching.

The underlying scripts can be run from anywhere, but expect to live inside this repo (`flake.nix` next to `scripts/`):

- `scripts/bootstrap_and_switch.sh`: standalone Home Manager bootstrap; write the local identity to a git-ignored `identity.nix` (read by `flake.nix`'s `defaultUser`) and mark it with `git add -N -f` so the flake can see it, enable flakes if needed, and run `home-manager switch`
  - This is not the primary macOS nix-darwin path. Use `darwin-rebuild switch --flake .#mbp` for nix-darwin.
  - On an interactive terminal, it asks whether to pass Home Manager's backup option for conflicting files.
  - Use `--backup` for a timestamped backup extension, `--backup backup` for `.backup`, or `--no-backup` to skip the prompt.
- `scripts/set-default-shell.sh`: add Fish to `/etc/shells` and `chsh` to it; useful for standalone Home Manager systems, not normally needed with nix-darwin
- `scripts/gc.sh`: garbage collect old Nix generations and unreachable store paths; on macOS, also clean Homebrew orphan dependencies, stale downloads, and cached downloads
  - By default it runs `nix-collect-garbage --delete-older-than 7d`, which keeps about one week of rollback history.
  - On NixOS and nix-darwin, it also runs the same Nix garbage collection through `sudo` when it detects a system profile. Use `--no-sudo` to limit cleanup to the current user, or `--sudo` to force root/system profile cleanup.
  - On macOS, it runs `brew autoremove`, `brew cleanup`, and `brew cleanup --scrub`. It does not run `brew bundle cleanup`; nix-darwin already removes undeclared Homebrew packages during activation because `homebrew.onActivation.cleanup = "zap"` is enabled.
  - Use `--dry-run` before the first real cleanup to inspect what supported tools would remove.
- `scripts/package.sh`: create a tarball under `packages/`; excludes build outputs and logs
- `scripts/update-blocked-casks.sh`: greedy-upgrade the casks whose vendor background updater is deliberately blocked (the `updater_blocked` list in the justfile), skipping any cask whose installed version is ahead of the catalog so a lagging Homebrew catalog never causes a downgrade; invoked by `just update-brew-blocked`

Examples:

```bash
./scripts/bootstrap_and_switch.sh
./scripts/bootstrap_and_switch.sh --target mbp-home
./scripts/bootstrap_and_switch.sh --target linux --backup
./scripts/set-default-shell.sh
./scripts/gc.sh --dry-run
./scripts/gc.sh
./scripts/gc.sh --older-than 14d --no-brew
```

## Nix helpers

The Home Manager and nix-darwin configurations register short Nix registry aliases:

- `n` points to this flake's stable `nixpkgs` input
- `u` points to this flake's unstable `nixpkgs-unstable` input

Examples:

```bash
nix shell n#jq
nix run u#some-package
```

`nix-index` answers which package provides a command or file. `comma` uses that index for one-shot command lookup and execution. For example, if `hello` is not installed:

```bash
, hello
```

The index database is provided by `nix-index-database` in the Home Manager generation.

## Flake maintenance

The flake exposes a formatter for supported systems:

```bash
nix fmt
```

`nix fmt -- --check` exits non-zero if any file is unformatted. The formatter, deadnix, statix, shellcheck, StyLua and Prettier are all run by `just check` (and CI).

It also exposes checks, grouped by system: the Home Manager activation packages, the nix-darwin system build, and the NixOS system toplevels:

```bash
nix flake check
```
