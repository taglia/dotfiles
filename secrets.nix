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
#               in bash, zsh and fish alike. Omit it for secrets consumed
#               directly as files; reference config.age.secrets.<name>.path
#               from a Home Manager module instead.
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
in
{
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
}
