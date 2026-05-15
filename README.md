# dotfiles (Nix + Home Manager)

This repo is a Nix flake that defines multiple Home Manager configurations (Linux + macOS).

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

- `linux-x86`
- `linux-x86-ai`
- `linux-x86-private`
- `linux-arm`
- `linux-arm-private`
- `apple`
- `apple-private`

If you're not sure, start with:

- Apple Silicon macOS: `apple`
- x86_64 Linux: `linux-x86`
- aarch64 Linux: `linux-arm`

## 5) Apply the configuration (home-manager switch)

You can run Home Manager without installing it globally:

```bash
nix run github:nix-community/home-manager/release-25.11 -- switch --flake .#apple
```

Replace `apple` with the target you chose, e.g.:

```bash
nix run github:nix-community/home-manager/release-25.11 -- switch --flake .#linux-x86
```

## 6) (Optional) Set Fish as your login shell

This repo enables `bash`, `zsh`, and `fish` via Home Manager. If you want to make Fish your login shell:

1) Ensure Fish is installed (it should be after `home-manager switch`):

```bash
command -v fish
```

2) Add that path to `/etc/shells` (required by `chsh`):

```bash
command -v fish | sudo tee -a /etc/shells
```

3) Change your login shell:

```bash
chsh -s "$(command -v fish)"
```

Log out and back in (or restart your terminal) to fully apply.

## Automation scripts

These scripts are meant to be run from the repo root (`flake.nix` next to them):

- `scripts/bootstrap.sh`: enable flakes (if needed) and run `home-manager switch`
- `scripts/set-default-shell.sh`: add Fish to `/etc/shells` and `chsh` to it

Examples:

```bash
./scripts/bootstrap.sh
./scripts/bootstrap.sh --target apple-private
./scripts/set-default-shell.sh
```

