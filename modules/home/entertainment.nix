{
  pkgs,
  lib,
  ...
}:

let
  # chess-tui's bot mode spawns whatever engine_path points at. Stockfish is
  # the default (it speaks UCI natively, no flag needed); gnuchess is
  # installed too, so `chess-tui -e "gnuchess --uci"` switches to it without
  # changing this file. chess-tui tolerates a read-only config (write errors
  # are logged, not fatal), so a symlink here is fine; in-TUI setting
  # changes just won't persist — fold anything worth keeping back into this
  # expression.
  chessTuiConfig = ''
    display_mode = "DEFAULT"
    engine_path = "${pkgs.stockfish}/bin/stockfish"
    log_level = "OFF"
    bot_depth = 10
    sound_enabled = false
    animations_enabled = false
  '';
in
{
  home.packages = with pkgs; [
    asciiquarium
    cmatrix
    nethack

    gnuchess
    stockfish
    chess-tui
  ];

  # chess-tui resolves its config dir via the `dirs` crate, which on macOS is
  # ~/Library/Application Support (not ~/.config). So deploy under the path
  # the host actually reads: the XDG location on Linux, the Application
  # Support location on Darwin. (Mirrors the glow config in xdg-files.nix.)
  xdg.configFile."chess-tui/config.toml" = lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin) {
    text = chessTuiConfig;
    force = true;
  };
  home.file."Library/Application Support/chess-tui/config.toml" =
    lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      text = chessTuiConfig;
      force = true;
    };
}