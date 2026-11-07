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

  # SECURITY PIN (2026-10-31): the Node runtime for everything Pi-related comes
  # from the *stable* channel, not unstable. nixos-unstable (and nixpkgs master)
  # still ship Node 24.21.0 linked against Brotli 1.2.0, which lack the October
  # 2026 Node security release (eight CVEs on the 24.x line) and the actively
  # exploited Brotli decoder bug CVE-2026-111497; the fixed Node 24.22.x and
  # Brotli 1.2.1 sit in staging. nixos-26.05 already carries Node 24.22.1 and
  # Brotli 1.2.1, cached for all three platforms. Revert to
  # `pkgs-unstable.nodejs` once nixos-unstable ships Node >= 24.22.1 with
  # Brotli >= 1.2.1 (see AGENTS.md, "Pending upstream checks").
  piNodejs = pkgs.nodejs;

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
  # swapping it is the only way to run Pi on the patched runtime. This rebuilds
  # the pi npm bundle locally (not Node itself).
  pi-coding-agent =
    (pkgs-unstable.pi-coding-agent.override {
      buildNpmPackage = pkgs-unstable.buildNpmPackage.override { nodejs = piNodejs; };
    }).overrideAttrs
      (prev: {
        # PACKAGING FIX (2026-11-07): Pi 1.5.0 added the `packages/schema`
        # workspace (`@earendil-works/pi-schema`), a runtime dependency of pi-ai.
        # nixpkgs' postInstall copies the other workspaces into node_modules but
        # not this one, then deletes its symlink as dangling, so `pi --version`
        # works while loading pi-ai (every extension, subagents) fails with
        # ERR_MODULE_NOT_FOUND. Copy it the same way nixpkgs does for the
        # others. Mirrors NixOS/nixpkgs#582756 and is a no-op once that lands
        # (see AGENTS.md, "Pending upstream checks").
        postInstall =
          prev.postInstall
          + lib.optionalString (!lib.hasInfix "pi-schema" prev.postInstall) ''
            cp -r packages/schema \
              "$out/lib/node_modules/pi-monorepo/node_modules/@earendil-works/pi-schema"
          '';
      });

  # PACKAGING FIX (2026-11-07): the locked nixos-unstable's opencode 2.2.5 has a
  # wrong `node_modules` fixed-output hash, so it fails to build on every
  # platform (nixpkgs issue #583797). Master already corrected it one day after
  # the locked revision (commit c399e1b7f, "opencode: fix hash") with
  # per-platform hashes; the Darwin one was reproduced locally. Apply the same
  # hashes while the broken one is still what nixpkgs declares; this is a no-op
  # once the fix reaches the lock (see AGENTS.md, "Pending upstream checks").
  opencode = pkgs-unstable.opencode.overrideAttrs (
    prev:
    lib.optionalAttrs
      (prev.node_modules.outputHash == "sha256-xfOVcw1+waLVNhFDwzOtzxrUSQEogvn88YomydOlhwc=")
      {
        node_modules = prev.node_modules.overrideAttrs {
          outputHash =
            if pkgs.stdenv.hostPlatform.isLinux then
              "sha256-prx9dX7kUvs/E3zopkaPk5LXh3xJAy5sZeum/W8L7cA="
            else
              "sha256-dIveiaiPFGSItwLyeMuPDxTE9gpvvnlTCB/+nG24qCc=";
        };
      }
  );
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
    opencode
    # nono sandboxes Pi on demand (`pi-sandbox` alias in pi.nix). Crush was
    # removed on 2026-10-31: its FSL license is unfree, so Hydra never caches
    # it and every unstable bump forced a full Go rebuild on every host.
    pkgs-unstable.nono
    pi-coding-agent
    pi-npm
  ];
}
