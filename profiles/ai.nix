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
  pi-coding-agent = pkgs-unstable.pi-coding-agent.override {
    buildNpmPackage = pkgs-unstable.buildNpmPackage.override { nodejs = piNodejs; };
  };

  # SECURITY PIN (2026-10-31): OpenCode is a Bun single-file executable, so it
  # embeds Bun's copy of Brotli. Bun < 1.4.4 carries the vulnerable Brotli
  # (CVE-2026-111497); nixpkgs still packages 1.4.2 (bump pending in
  # NixOS/nixpkgs#574334). Build OpenCode with Bun 1.4.4 until unstable
  # catches up, then drop `bun-fixed` and use `pkgs-unstable.opencode` again.
  # `src` and the download URLs read `finalAttrs.version`/`passthru.sources`,
  # so overriding those two is enough.
  bun-fixed = pkgs-unstable.bun.overrideAttrs (
    finalAttrs: _prev: {
      version = "1.4.4";
      # Tell mkDerivation the version bump is deliberate (silences its warning).
      __intentionallyOverridingVersion = true;
      passthru.sources =
        let
          release = "https://github.com/oven-sh/bun/releases/download/bun-v${finalAttrs.version}";
        in
        {
          "aarch64-darwin" = pkgs-unstable.fetchurl {
            url = "${release}/bun-darwin-aarch64.zip";
            hash = "sha256-wkDX8My5DCY6hJ/NsJt+5iYw2SE0jtaq/ahrnVd7xRA=";
          };
          "aarch64-linux" = pkgs-unstable.fetchurl {
            url = "${release}/bun-linux-aarch64.zip";
            hash = "sha256-uqa7NvUdblhWHgK76oJQOKnfRU9nPW13bou/hvjHhQ4=";
          };
          "x86_64-linux" = pkgs-unstable.fetchurl {
            url = "${release}/bun-linux-x64-baseline.zip";
            hash = "sha256-4ERutVmVdy65iUvrrppr42jZhai5Jx7hJEhvmUbu3XY=";
          };
        };
    }
  );
  opencode = pkgs-unstable.opencode.override { bun = bun-fixed; };
in

{
  imports = [
    ../modules/home/claude-code.nix
    ../modules/home/opencode.nix
    ../modules/home/pi.nix
    ../modules/home/crush.nix
  ];

  # Makes the configured unstable instance above available to the imported
  # modules as an ordinary module argument (crush.nix takes `pkgs-unstable`),
  # keeping it a real module instead of a hand-applied function. `piNodejs`
  # is passed the same way so pi.nix cannot drift to a different runtime.
  _module.args = { inherit pkgs-unstable piNodejs; };

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
    # claude-code is also a Bun executable, but upstream already builds it with
    # Bun 1.4.4 (checked on 2.1.303 via the embedded `bun/1.4.4` string), so
    # no override is needed. codex, crush, nono and ollama are Rust/Go and do
    # not link the Brotli C library.
    pkgs-unstable.claude-code
    pkgs-unstable.codex
    opencode
    # crush is installed via the wrapper in modules/home/crush.nix, which
    # references the real binary by absolute store path and shadows it in
    # PATH to block unreviewed project-local config. nono is installed for
    # manual sandboxing (see crush.nix); the wrapper does not invoke it.
    pkgs-unstable.nono
    pi-coding-agent
    pi-npm
  ];
}
