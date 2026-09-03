{
  inputs,
  pkgs,
  lib,
  ...
}:

let
  # A second nixpkgs (unstable) is imported here so this profile can pull a few
  # fast-moving tools ahead of the stable channel. Other modules reuse the
  # flake's shared `inputs.nixpkgs-unstable.legacyPackages` evaluation; this
  # configured import is the single extra one, and the unfree allowance stays
  # scoped to exactly the packages we opt into.
  pkgs-unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;

    # crush is FSL-1.1-MIT: unfree per nixpkgs (non-compete clause) but
    # redistributable, so it must be opted into here like claude-code.
    config.allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "claude-code"
        "crush"
      ];
  };

  # nono's test suite is highly environment-sensitive (it tests sandboxing:
  # Landlock, $PWD resolution, tmpdir validation), and nixpkgs' skip list is
  # tuned for Hydra's sandboxed NixOS builders only. Elsewhere other tests
  # fail: on darwin one more test hits the "/nix overlaps protected nono
  # state root" problem, and on the Debian box ~44 tests fail. Any override
  # already forfeits the binary cache and forces a local build, so skip the
  # check phase entirely rather than chasing per-machine skip lists. Drop
  # this override once nixpkgs PR #558782 lands in our pinned unstable;
  # AGENTS.md tracks that.
  nono = pkgs-unstable.nono.overrideAttrs (_: {
    doCheck = false;
  });

  # Keep Pi's package-manager Node runtime aligned with the Node runtime used
  # by the unstable Pi package. This avoids PATH-dependent npm resolution and
  # native-module/SQLite ABI mismatches when Pi installs extensions. Put the
  # release-age policy on the command line so project-level npm configuration
  # cannot silently relax it for packages installed by Pi.
  pi-npm = pkgs-unstable.writeShellScriptBin "pi-npm" ''
    exec ${pkgs-unstable.nodejs}/bin/npm --min-release-age=10 "$@"
  '';
in

{
  imports = [
    ../modules/home/claude-code.nix
    ../modules/home/opencode.nix
    ../modules/home/pi.nix
    ../modules/home/crush.nix
    ../modules/home/goose.nix
  ];

  # Makes the configured unstable instance above available to the imported
  # modules as an ordinary module argument (crush.nix and goose.nix take
  # `pkgs-unstable`), keeping them real modules instead of hand-applied
  # functions.
  _module.args.pkgs-unstable = pkgs-unstable;

  # `services.ollama` installs the `ollama` package itself and runs
  # `ollama serve` as a managed background service: a user LaunchAgent
  # (KeepAlive, ProcessType=Background) on macOS and a systemd user service
  # on Linux. Pinning the package to unstable tracks fast-moving model/runner
  # support ahead of the stable channel. ollama is MIT-licensed, so no unfree
  # predicate is needed in the `pkgs-unstable` import above.
  services.ollama = {
    enable = true;
    package = pkgs-unstable.ollama;
  };

  home.packages = [
    # Pinned to the stable channel, not unstable: rtk 0.43.0 (in nixos-unstable
    # at the time of writing) fails its check build because its own
    # `[lints.rust] warnings = "deny"` turns two dead-code items (exposed only in
    # the test build by Rust's new dead_code_pub_in_binary analysis) into hard
    # errors. The upstream fix (`env.RUSTFLAGS = "--cap-lints warn"`) is in
    # nixpkgs master but had not reached `nixos-unstable` yet. Stable ships
    # rtk 0.41.0, whose older Rust toolchain predates that analysis, so it
    # builds cleanly. Move back to unstable once nixos-unstable carries the
    # fix and you want the newer release.
    pkgs.rtk
    pkgs-unstable.claude-code
    pkgs-unstable.codex
    # goose-cli is installed via the wrapper in modules/home/goose.nix so its
    # provider credentials can be loaded from agenix only at runtime.
    pkgs-unstable.opencode
    # crush is installed via the wrapper in modules/home/crush.nix, which
    # references the real binary by absolute store path and shadows it in
    # PATH to block unreviewed project-local config. nono is installed for
    # manual sandboxing (see crush.nix); the wrapper does not invoke it.
    nono
    pkgs-unstable.pi-coding-agent
    pi-npm
  ];
}
