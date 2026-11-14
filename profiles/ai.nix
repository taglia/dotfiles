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

    config.allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "claude-code"
      ];
  };

  # One Node runtime for everything Pi-related: the Pi package, the pi-npm
  # wrapper and the `node`/`npm` that pi.nix puts on PATH. It tracks the
  # unstable channel like Pi itself. (From 2026-10-31 to 2026-11-14 this was
  # pinned to stable `pkgs.nodejs` while unstable lagged on the October 2026
  # Node security release and Brotli CVE-2026-111497; unstable has carried
  # Node 24.22.2 / Brotli 1.2.1 since.) The November 2026 Node security release
  # (24.22.3) is not in either channel yet; see AGENTS.md, "Pending upstream
  # checks".
  piNodejs = pkgs-unstable.nodejs;

  # Keep Pi's package-manager Node runtime aligned with the Node runtime used
  # by the Pi package (both are `piNodejs`). This avoids PATH-dependent npm
  # resolution and native-module/SQLite ABI mismatches when Pi installs
  # extensions. Put the release-age policy on the command line so
  # project-level npm configuration cannot silently relax it for packages
  # installed by Pi.
  pi-npm = pkgs-unstable.writeShellScriptBin "pi-npm" ''
    exec ${piNodejs}/bin/npm --min-release-age=10 "$@"
  '';

  # Pi's `bin/pi` wrapper execs the Node that buildNpmPackage was given, so
  # pass `piNodejs` explicitly: Pi then runs on the same runtime as pi-npm even
  # if `piNodejs` is pinned to another channel again. While `piNodejs` is
  # unstable's own nodejs this yields the unmodified, cached nixpkgs package.
  pi-coding-agent = pkgs-unstable.pi-coding-agent.override {
    buildNpmPackage = pkgs-unstable.buildNpmPackage.override { nodejs = piNodejs; };
  };
in

{
  imports = [
    ../modules/home/claude-code.nix
    ../modules/home/opencode.nix
    ../modules/home/pi.nix
  ];

  # Passes the shared Node runtime to pi.nix as an ordinary module argument,
  # so it cannot drift to a different runtime than the one used here.
  _module.args = { inherit piNodejs; };

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
    # claude-code and opencode are Bun executables, so they embed Bun's copy of
    # Brotli (CVE-2026-111497, fixed in Bun 1.4.4). Upstream builds claude-code
    # with Bun 1.4.4 (checked on 2.1.303 via the embedded `bun/1.4.4` string),
    # and nixos-unstable builds opencode with its own bun 1.4.4 since
    # 2026-11-07 (the temporary `bun-fixed` override was dropped then). codex,
    # nono and ollama are Rust/Go and do not link the Brotli C library.
    pkgs-unstable.claude-code
    pkgs-unstable.codex
    pkgs-unstable.opencode
    # nono sandboxes Pi on demand (`pi-sandbox` alias in pi.nix). Crush was
    # removed on 2026-10-31: its FSL license is unfree, so Hydra never caches
    # it and every unstable bump forced a full Go rebuild on every host.
    pkgs-unstable.nono
    pi-coding-agent
    pi-npm
  ];
}
