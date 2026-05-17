{ pkgs-unstable, ... }:

{
  home.packages = [
    pkgs-unstable.rtk
    pkgs-unstable.claude-code
    pkgs-unstable.codex
    pkgs-unstable.opencode
    pkgs-unstable.ollama
  ];
}
