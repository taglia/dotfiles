# Generic agenix wiring: everything is derived from ../secrets.nix, the single
# source of truth for secrets (see the comment there). To add a secret, edit
# only ../secrets.nix; this file should not need per-secret changes.
# secretsMachine (passed via extraSpecialArgs from lib/hosts.nix) names the
# entry in ../secrets-machines.nix this host decrypts secrets as. It is
# declared statically per host because flakes' pure evaluation makes
# builtins.pathExists return false for absolute paths outside the store, so
# probing identity files at eval time silently matches nothing.
{
  config,
  lib,
  secretsMachine ? null,
  ...
}:

let
  rules = import ../secrets.nix;
  machines = import ../secrets-machines.nix;

  # age secret names are derived from the file name, keeping the historical
  # underscore form: secrets/pi-kagi-api-key.age -> pi_kagi_api_key.
  toName =
    path: lib.replaceStrings [ "-" ] [ "_" ] (lib.removeSuffix ".age" (builtins.baseNameOf path));

  # Wire only secrets whose .age payload is present, so hosts (or forks)
  # without the payloads keep evaluating.
  active = lib.filterAttrs (path: _: builtins.pathExists (../. + "/${path}")) rules;

  # The machine key this host decrypts secrets as, by name (see the header
  # comment). Null = no secrets wired (hosts without a secretsMachine).
  localPubKeys = lib.optional (secretsMachine != null) machines.${secretsMachine}.publicKey;

  # Wire only secrets this machine can actually decrypt. The agenix
  # activation script runs with `errexit` and decrypts every wired secret, so
  # wiring a non-recipient secret aborts activation midway (before the
  # agenix -> agenix.d/N symlink is created) on machines holding a different
  # key set. Filtering here keeps the recipient lists in secrets.nix as the
  # single authorization point.
  decryptable = lib.filterAttrs (
    _: rule: builtins.any (k: builtins.elem k localPubKeys) rule.publicKeys
  ) active;
  withEnvVarFile = lib.filterAttrs (_: rule: rule ? envVarFile) decryptable;

  # A duplicated envVarFile among decryptable secrets would silently pick a
  # winner in home.sessionVariables, so it must fail the build instead (see
  # the assertion below).
  envVarNames = map (rule: rule.envVarFile) (builtins.attrValues withEnvVarFile);
  duplicatedNames = lib.subtractLists (lib.unique envVarNames) envVarNames;

  # Every declared machine identity; activation silently skips paths not
  # present on the local machine (agenix does `test -r` per identity), so each
  # machine ends up using its own key. Non-recipient keys never trigger a
  # passphrase prompt: age checks a stanza's recipient tag (derived from the
  # public key, readable without the passphrase) before touching a private
  # key.
  identities = lib.unique (map (m: m.identity) (builtins.attrValues machines));
in
{
  assertions = [
    {
      assertion = duplicatedNames == [ ];
      message = ''
        secrets.nix: this machine can decrypt multiple secrets exporting the
        same environment variable(s): ${lib.concatStringsSep ", " duplicatedNames}.
        home.sessionVariables would silently pick one; make the recipient
        lists disjoint (or the envVarFile names distinct) so exactly one
        decryptable secret exports each variable.'';
    }
  ];

  age.identityPaths = identities;

  age.secrets = lib.mapAttrs' (
    path: _: lib.nameValuePair (toName path) { file = ../. + "/${path}"; }
  ) decryptable;

  # Export only the decrypted file *path* (never the secret value), keeping
  # secrets out of the Nix store. home.sessionVariables is shell-agnostic:
  # Home Manager exports it for bash, zsh and fish (and the systemd user
  # environment on Linux).
  home.sessionVariables = lib.mapAttrs' (
    path: rule: lib.nameValuePair rule.envVarFile config.age.secrets.${toName path}.path
  ) withEnvVarFile;

  programs.atuin.settings = {
    auto_sync = true;
    sync_frequency = "5m";
  };
}
