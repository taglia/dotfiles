# Generic agenix wiring: everything is derived from ../secrets.nix, the single
# source of truth for secrets (see the comment there). To add a secret, edit
# only ../secrets.nix; this file should not need per-secret changes.
{ config, lib, ... }:

let
  rules = import ../secrets.nix;

  # age secret names are derived from the file name, keeping the historical
  # underscore form: secrets/pi-kagi-api-key.age -> pi_kagi_api_key.
  toName =
    path: lib.replaceStrings [ "-" ] [ "_" ] (lib.removeSuffix ".age" (builtins.baseNameOf path));

  # Wire only secrets whose .age payload is present, so hosts (or forks)
  # without the payloads keep evaluating.
  active = lib.filterAttrs (path: _: builtins.pathExists (../. + "/${path}")) rules;
  withEnvVarFile = lib.filterAttrs (_: rule: rule ? envVarFile) active;

  # Every declared machine identity; activation silently skips paths not
  # present on the local machine (agenix does `test -r` per identity), so each
  # machine ends up using its own key. Non-recipient keys never trigger a
  # passphrase prompt: age checks a stanza's recipient tag (derived from the
  # public key, readable without the passphrase) before touching a private
  # key.
  identities = lib.unique (
    map (m: m.identity) (builtins.attrValues (import ../secrets-machines.nix))
  );
in
{
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
