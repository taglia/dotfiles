# dotfiles (Nix + Home Manager + nix-darwin)

This repo is a Nix flake that defines Home Manager configurations for Linux and macOS, plus a nix-darwin configuration for macOS system-level setup.

## Prerequisites

- Nix installed
  - Recommended (macOS + Linux): Determinate Systems Nix Installer
  - Alternative: Official Nix installer
- Build tools
  - macOS: install Xcode Command Line Tools: `xcode-select --install`
  - Linux: install your distro's build essentials (e.g. `build-essential`, `gcc`, `make`, etc.)

## 1) Install Nix

If you use the Determinate installer:

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
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
```

## 4) Pick a target

Targets are defined in `flake.nix` under `homeConfigurations`:

- `mbp-home`
- `mbp` (legacy Home Manager-only alias for `mbp-home`)
- `linux`
- `linux-ai`
- `linux-private`
- `linux-minimal`
- `linux-aws` (uses local user `admin`)
- `linux-arm`
- `linux-minimal-arm`

Each target always includes the base profile. The Linux or macOS profile is selected from the target system in `flake.nix`, and the `ai` / `private` suffixes add those extra profile layers.

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

Then switch when ready:

```bash
darwin-rebuild switch --flake .#mbp
```

`darwin-rebuild switch` also activates the integrated Home Manager configuration for `taglia`.

Homebrew and Mac App Store apps are declared in `modules/darwin/homebrew.nix`. Current activation behavior is intentionally declarative:

- declared brews, casks, and MAS apps are installed if missing
- Homebrew metadata is updated during activation
- installed Homebrew formulae and casks are upgraded during activation
- undeclared Homebrew and MAS apps can be removed, including related support files where Homebrew supports zapping, because `cleanup = "zap"` is enabled

Mac App Store apps require the Mac to be signed into an Apple ID that owns those apps. Keep `homebrew.masApps` complete when cleanup is enabled.

Possible future improvement: `nix-homebrew` can make the Homebrew installation and taps more reproducible while still using the official Homebrew taps.

Native Nix packages installed into the nix-darwin system profile live in `modules/darwin/packages.nix`. macOS settings, fonts, Finder settings, and similar system preferences live in `modules/darwin/settings.nix`.

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

AeroSpace is managed directly by nix-darwin through `services.aerospace`.

## Secrets

This repo uses `agenix` for encrypted secrets. Keep `secrets.nix` initialized as an empty rule set until the first secret is needed:

```nix
{ }
```

Best practice is to use a dedicated age key per machine instead of reusing a personal SSH key. A machine-specific age key keeps secret decryption separate from SSH access, makes rotation simpler, and avoids depending on an SSH key that may be loaded into agents or synced by other tools.

Create a machine key:

```bash
mkdir -p ~/.config/age
age-keygen -o ~/.config/age/keys.txt
age-keygen -y ~/.config/age/keys.txt
```

The final command prints the public recipient, which starts with `age1...`. Add that recipient to `secrets.nix` only when adding a secret:

```nix
let
  mbp = "age1...";
in
{
  "secrets/example-api-token.age".publicKeys = [ mbp ];
}
```

Use machine-specific names such as `mbp`, `linux_workstation`, or `server_name`; avoid a generic personal name for machine recipients. Commit only encrypted `.age` files and `secrets.nix`, never `~/.config/age/keys.txt`.

Create or edit the secret from the repo root:

```bash
mkdir -p secrets
agenix -e secrets/example-api-token.age -i ~/.config/age/keys.txt
```

For an API token, the editor buffer can contain either a raw token:

```text
ghp_exampletokenvalue
```

or an environment-file style value if a service expects an env file:

```sh
EXAMPLE_API_TOKEN=ghp_exampletokenvalue
```

If recipient keys change, re-encrypt existing secrets:

```bash
agenix -r -i ~/.config/age/keys.txt
```

When a secret is consumed by Home Manager, declare the identity path explicitly in the profile that uses secrets:

```nix
{ config, ... }:

{
  age.identityPaths = [ "${config.home.homeDirectory}/.config/age/keys.txt" ];
  age.secrets.example_api_token.file = ../secrets/example-api-token.age;
}
```

After activation, `agenix` decrypts the secret to a runtime file and exposes its path as `config.age.secrets.example_api_token.path`. The important rule is to pass that path around, not the secret value. Do not use `builtins.readFile` on a decrypted secret or put the token directly in `home.sessionVariables`, because that would copy the secret into the Nix store or generated config files.

For a command-line tool that can read a token from a file, pass the path:

```nix
{ config, ... }:

{
  age.identityPaths = [ "${config.home.homeDirectory}/.config/age/keys.txt" ];
  age.secrets.example_api_token.file = ../secrets/example-api-token.age;

  home.sessionVariables.EXAMPLE_API_TOKEN_FILE = config.age.secrets.example_api_token.path;
}
```

Then scripts can read the token at runtime:

```bash
token="$(cat "$EXAMPLE_API_TOKEN_FILE")"
curl -H "Authorization: Bearer $token" https://api.example.com/me
```

For a user service that expects environment variables, store the secret as an env file (`EXAMPLE_API_TOKEN=...`) and point the service at the decrypted file:

```nix
{ config, pkgs, ... }:

{
  age.identityPaths = [ "${config.home.homeDirectory}/.config/age/keys.txt" ];
  age.secrets.example_api_env.file = ../secrets/example-api-token.age;

  systemd.user.services.example-api-sync = {
    Unit.Description = "Example API sync";
    Service = {
      EnvironmentFile = config.age.secrets.example_api_env.path;
      ExecStart = "${pkgs.curl}/bin/curl -H \"Authorization: Bearer $EXAMPLE_API_TOKEN\" https://api.example.com/me";
    };
  };
}
```

Using an SSH key as an age identity can be convenient for one-off local use, but it is not the preferred default for this repo. Use SSH only when the key is already machine-specific, not broadly reused, and you are comfortable with SSH access and secret decryption sharing the same credential lifecycle.

## Automation scripts

Common tasks are exposed through `just`:

```bash
just
just switch-darwin
just switch-home linux
just check
just gc --dry-run
just update-all
```

`just switch-home` requires a target argument, e.g. `just switch-home mbp-home` or `just switch-home linux`. `just update-all` updates all flake inputs; use `just update-unstable` to update only `nixpkgs-unstable`.

The underlying scripts can be run from anywhere, but expect to live inside this repo (`flake.nix` next to `scripts/`):

- `scripts/bootstrap_and_switch.sh`: standalone Home Manager bootstrap; update local identity in `flake.nix`, enable flakes if needed, and run `home-manager switch`
  - This is not the primary macOS nix-darwin path. Use `darwin-rebuild switch --flake .#mbp` for nix-darwin.
  - On an interactive terminal, it asks whether to pass Home Manager's backup option for conflicting files.
  - Use `--backup` for a timestamped backup extension, `--backup backup` for `.backup`, or `--no-backup` to skip the prompt.
- `scripts/set-default-shell.sh`: add Fish to `/etc/shells` and `chsh` to it; useful for standalone Home Manager systems, not normally needed with nix-darwin
- `scripts/update-pkgs-unstable.sh`: update only the `nixpkgs-unstable` input
- `scripts/gc.sh`: garbage collect old Nix generations and unreachable store paths; on macOS, also clean Homebrew orphan dependencies and stale cache files
  - By default it runs `nix-collect-garbage --delete-older-than 7d`, which keeps about one week of rollback history.
  - On NixOS and nix-darwin, it also runs the same Nix garbage collection through `sudo` when it detects a system profile. Use `--no-sudo` to limit cleanup to the current user, or `--sudo` to force root/system profile cleanup.
  - On macOS, it runs `brew autoremove` and `brew cleanup`. It does not run `brew bundle cleanup`; nix-darwin already removes undeclared Homebrew packages during activation because `homebrew.onActivation.cleanup = "zap"` is enabled.
  - Use `--dry-run` before the first real cleanup to inspect what supported tools would remove.
- `scripts/package.sh`: create a tarball under `packages/`; excludes build outputs and logs

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

It also exposes Home Manager activation-package checks, grouped by system:

```bash
nix flake check
```
