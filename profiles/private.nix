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
  pkgs,
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

  # Resolve a secrets.nix `path` (which may be $HOME-relative, to keep
  # secrets.nix portable across /Users/* and /home/* hosts) to an absolute
  # path. agenix's Darwin activation runs from a launchd agent whose CWD is
  # / (read-only on modern macOS), so a bare relative path would make its
  # `mkdir -p`/`ln -sfT` abort under errexit. Absolute paths are passed
  # through unchanged.
  resolvePath =
    rulePath:
    if lib.hasPrefix "/" rulePath then rulePath else "${config.home.homeDirectory}/${rulePath}";

  # agenix's Home Manager module deliberately keeps $XDG_RUNTIME_DIR as a
  # shell expression in its default Linux path.  That works in the systemd
  # user service, but exporting the resulting path through
  # home.sessionVariables is fragile: shells without XDG_RUNTIME_DIR turn
  # `${XDG_RUNTIME_DIR}/agenix/foo` into `/agenix/foo`.  Give secrets exposed
  # through envVarFile a stable, cross-platform consumer symlink while their
  # decrypted backing files remain in agenix's per-OS runtime directory.
  # The directory constant is shared with the runtime consumers (goose.nix,
  # crush.nix) through ../lib/secrets-runtime.nix.
  secretsRuntime = import ../lib/secrets-runtime.nix;
  envFilePath = name: "${config.home.homeDirectory}/${secretsRuntime.dir}/${name}";
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

  # agenix currently sets both `Crashed = false` and
  # `SuccessfulExit = false` in its macOS KeepAlive dictionary. launchd
  # treats those as independent conditions, so `Crashed = false` restarts
  # the one-shot agent after every clean exit. Keep only the intended retry
  # condition: restart after a failed decryption, but stop after success.
  launchd.agents.activate-agenix.config.KeepAlive = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
    lib.mkForce { SuccessfulExit = false; }
  );

  # On Linux the agenix unit is a one-shot service. Without RemainAfterExit it
  # immediately becomes inactive, so Home Manager's sd-switch can miss that
  # its ExecStart changed when an encrypted input gets a new store path. Keep
  # the successful unit active so later switches restart it and decrypt the
  # new generation.
  systemd.user.services.agenix.Service.RemainAfterExit =
    lib.mkIf pkgs.stdenv.hostPlatform.isLinux true;

  # A `path` field in secrets.nix deploys a secret to a fixed filesystem
  # location (as a force-symlink) rather than agenix's default runtime dir;
  # resolvePath (defined in the let above) makes that absolute so Darwin's
  # launchd-activated mount script (CWD /) can `mkdir -p`/`ln -sfT` it without
  # aborting under errexit.
  age.secrets = lib.mapAttrs' (
    path: rule:
    let
      name = toName path;
    in
    lib.nameValuePair name (
      {
        file = ../. + "/${path}";
      }
      // lib.optionalAttrs (rule ? path) { path = resolvePath rule.path; }
      // lib.optionalAttrs (!(rule ? path) && rule ? envVarFile) { path = envFilePath name; }
    )
  ) decryptable;

  # Export only the decrypted file *path* (never the secret value), keeping
  # secrets out of the Nix store. home.sessionVariables is shell-agnostic:
  # Home Manager exports it for bash, zsh and fish (and the systemd user
  # environment on Linux).
  home.sessionVariables = lib.mapAttrs' (
    path: rule: lib.nameValuePair rule.envVarFile config.age.secrets.${toName path}.path
  ) withEnvVarFile;

  # Host-scoped extra for private machines, not agenix wiring: atuin sync is
  # configured only where this profile is imported, because those are the
  # machines that get logged into the sync server (syncing is ultimately
  # gated by that login, not by this block). History leaves the machine
  # end-to-end encrypted; secrets_filter is atuin's built-in skip of
  # commands that look like they contain credentials — its current default,
  # pinned here because history is synced off-machine.
  programs.atuin.settings = {
    auto_sync = true;
    sync_frequency = "5m";
    secrets_filter = true;
  };
}
