{ pkgs, pkgs-unstable, ... }:

{
  home.packages = with pkgs; [
    claude-code
    pkgs-unstable.codex
    opencode
    ollama
  ];
}
