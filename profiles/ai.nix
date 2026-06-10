{ nixpkgs-unstable, pkgs, ... }:

let
  pkgs-unstable = import nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;

    config = {
      allowUnfreePredicate =
        pkg:
        builtins.elem (pkg.pname or pkg.name) [
          "claude-code"
        ];
    };
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
