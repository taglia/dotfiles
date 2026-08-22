# Single source of truth for agenix secrets.
#
# Each entry maps an .age file (payloads live under secrets/) to:
#
#   publicKeys  SSH recipients allowed to decrypt the secret, from
#               secrets-machines.nix. This is where machine authorization
#               lives: only a machine holding one of the matching private
#               keys (the identity paths in secrets-machines.nix) can decrypt
#               the payload.
#
#   envVarFile  (optional) Name of an environment variable that will contain
#               the *path* to the decrypted file at runtime - never the secret
#               value, so secrets stay out of the Nix store. The variable is
#               exported via home.sessionVariables and is therefore available
#               in bash, zsh and fish alike. Its value is a stable symlink at
#               ~/.local/share/agenix/<name>; the decrypted backing file stays
#               in agenix's runtime directory. Omit it for secrets consumed
#               directly as files; reference config.age.secrets.<name>.path
#               from a Home Manager module instead.
#
#   path        (optional) Custom deployment path for the decrypted secret,
#               relative to $HOME. When set, agenix symlinks the secret to
#               this location at activation with `ln -sfT`, atomically
#               replacing any existing file or symlink on every switch. Use
#               for secrets that must live at a fixed filesystem location
#               (e.g. "~/.ssh/config"). Omit it to keep agenix's default
#               runtime location; the secret is then reachable only via
#               envVarFile or config.age.secrets.<name>.path.
#
# The agenix CLI only reads publicKeys/armor from this file; envVarFile is
# consumed by profiles/private.nix, which derives age.secrets and
# home.sessionVariables automatically. To add a secret: add one entry here,
# encrypt with `agenix -e <path>`, and rebuild - no other edits needed.
let
  machines = import ./secrets-machines.nix;
  mbp = machines.mbp.publicKey;
  dev-vm = machines.dev-vm.publicKey;
  utm-vm = machines.utm-vm.publicKey;
  openclaw-hetzner = machines.openclaw-hetzner.publicKey;
in
{
  "secrets/ssh-config.age" = {
    publicKeys = [
      mbp
      dev-vm
      utm-vm
    ];
    # Deployed in place as ~/.ssh/config (agenix force-symlinks it on every
    # switch via ln -sfT; SSH follows the symlink). See the header for `path`.
    path = ".ssh/config";
  };
  "secrets/pi-kagi-api-key.age" = {
    publicKeys = [
      mbp
      dev-vm
      utm-vm
    ];
    envVarFile = "KAGI_API_KEY_FILE";
  };
  "secrets/pi-ollama-api-key.age" = {
    publicKeys = [
      mbp
      dev-vm
      utm-vm
    ];
    envVarFile = "OLLAMA_API_KEY_FILE";
  };
  "secrets/pi-moonshot-api-key.age" = {
    publicKeys = [
      mbp
      dev-vm
      utm-vm
    ];
    envVarFile = "MOONSHOT_API_KEY_FILE";
  };
  "secrets/opencode-zen-api-key.age" = {
    publicKeys = [
      mbp
      dev-vm
      utm-vm
    ];
    envVarFile = "ZEN_API_KEY_FILE";
  };
  "secrets/openrouter-api-key.age" = {
    publicKeys = [
      mbp
      dev-vm
      utm-vm
    ];
    envVarFile = "OPENROUTER_API_KEY_FILE";
  };
  "secrets/openclaw-moonshot-api-key.age" = {
    publicKeys = [
      openclaw-hetzner
    ];
    envVarFile = "MOONSHOT_API_KEY_FILE";
  };
  "secrets/openclaw-kagi-api-key.age" = {
    publicKeys = [
      openclaw-hetzner
    ];
    envVarFile = "KAGI_API_KEY_FILE";
  };
  "secrets/openclaw-ollama-api-key.age" = {
    publicKeys = [
      openclaw-hetzner
    ];
    envVarFile = "OLLAMA_API_KEY_FILE";
  };
}
