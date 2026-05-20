# dotfiles (Nix + Home Manager)

This repo is a Nix flake that defines multiple Home Manager configurations for Linux and macOS.

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

## 3) Clone the repo

```bash
git clone <this-repo-url> ~/dotfiles
cd ~/dotfiles
```

## 4) Pick a Home Manager target

Targets are defined in `flake.nix` under `homeConfigurations`:

- `mbp`
- `linux`
- `linux-ai`
- `linux-private`
- `linux_arm`

Each target always includes the base profile. The Linux or macOS profile is selected from the target system in `flake.nix`, and the `ai` / `private` suffixes add those extra profile layers.

If you're not sure, start with:

- MacBook Pro: `mbp`
- x86_64 Linux: `linux`
- aarch64 Linux: `linux_arm`

## 5) Apply the configuration (home-manager switch)

You can run Home Manager without installing it globally:

```bash
nix run github:nix-community/home-manager/release-25.11 -- switch --flake .#mbp
```

Replace `mbp` with the target you chose, e.g.:

```bash
nix run github:nix-community/home-manager/release-25.11 -- switch --flake .#linux
```

## 6) (Optional) Set Fish as your login shell

This repo enables `bash`, `zsh`, and `fish` via Home Manager. If you want to make Fish your login shell:

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

## Automation scripts

These scripts can be run from anywhere, but expect to live inside this repo (`flake.nix` next to `scripts/`):

- `scripts/bootstrap_and_switch.sh`: update local identity in `flake.nix`, enable flakes if needed, and run `home-manager switch`
  - On an interactive terminal, it asks whether to pass Home Manager's backup option for conflicting files.
  - Use `--backup` for a timestamped backup extension, `--backup backup` for `.backup`, or `--no-backup` to skip the prompt.
- `scripts/set-default-shell.sh`: add Fish to `/etc/shells` and `chsh` to it
- `scripts/update-pkgs-unstable.sh`: update only the `nixpkgs-unstable` input
- `scripts/package.sh`: create a tarball under `packages/`

Examples:

```bash
./scripts/bootstrap_and_switch.sh
./scripts/bootstrap_and_switch.sh --target mbp
./scripts/bootstrap_and_switch.sh --target mbp --backup
./scripts/set-default-shell.sh
```

## Flake maintenance

The flake exposes a formatter for supported systems:

```bash
nix fmt
```

It also exposes Home Manager activation-package checks, grouped by system:

```bash
nix flake check
```
