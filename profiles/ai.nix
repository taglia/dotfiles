{
  inputs,
  pkgs,
  lib,
  ...
}:

let
  # A second nixpkgs (unstable) is imported here so this profile can pull a few
  # fast-moving tools ahead of the stable channel. Only this profile uses
  # unstable, so it is the single extra nixpkgs evaluation in the flake, and the
  # unfree allowance stays scoped to exactly the packages we opt into.
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
    ../modules/home/opencode.nix
    ../modules/home/pi.nix
    ../modules/home/crush.nix
  ];

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
    pkgs-unstable.opencode
    pkgs-unstable.crush
    pkgs-unstable.nono
    pkgs-unstable.pi-coding-agent
    pi-npm
  ];
}
