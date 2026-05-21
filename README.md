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
