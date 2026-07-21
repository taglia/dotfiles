# Generic agenix wiring: everything is derived from ../secrets.nix, the single
# source of truth for secrets (see the comment there). To add a secret, edit
# only ../secrets.nix; this file should not need per-secret changes.
{ config, lib, ... }:

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
  withEnvVarFile = lib.filterAttrs (_: rule: rule ? envVarFile) active;

  # Machines whose private identity file exists on this host: the eval-time
  # approximation of "keys this machine can decrypt with" (agenix makes the
  # same determination at activation via `test -r`). Correct because switches
  # run on the target machine itself.
  localPubKeys = map (m: m.publicKey) (
    builtins.filter (m: builtins.pathExists m.identity) (builtins.attrValues machines)
  );

  # Secrets this machine can actually decrypt, limited to those exporting an
  # env var. A duplicated envVarFile here would silently pick a winner in
  # home.sessionVariables, so it must fail the build instead (see the
  # assertion below).
  decryptableWithEnvVar = builtins.filter (
    rule: builtins.any (k: builtins.elem k localPubKeys) rule.publicKeys
  ) (builtins.attrValues withEnvVarFile);

  envVarNames = map (rule: rule.envVarFile) decryptableWithEnvVar;
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
  ) active;

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
