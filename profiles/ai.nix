{
  nixpkgs-unstable,
  pkgs,
  lib,
  ...
}:

let
  # A second nixpkgs (unstable) is imported here so this profile can pull a few
  # fast-moving tools ahead of the stable channel. Only this profile uses
  # unstable, so it is the single extra nixpkgs evaluation in the flake, and the
  # unfree allowance stays scoped to exactly the packages we opt into.
  pkgs-unstable = import nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;

    config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "claude-code" ];
  };
in

{
  home.packages = [
    pkgs-unstable.rtk
    pkgs-unstable.claude-code
    pkgs-unstable.codex
    pkgs-unstable.opencode
  ]
  ++ pkgs.lib.optionals (!pkgs.stdenv.hostPlatform.isDarwin) [
    pkgs-unstable.ollama
  ];
}
