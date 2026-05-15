{ pkgs-unstable, ... }:

{
  home.packages = [
    pkgs-unstable.claude-code
    pkgs-unstable.codex
    pkgs-unstable.opencode
    pkgs-unstable.ollama
  ];
}
