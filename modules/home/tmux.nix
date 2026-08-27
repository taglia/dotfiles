{ pkgs, ... }:

let
  catppuccinScript = "${pkgs.tmuxPlugins.catppuccin}/share/tmux-plugins/catppuccin/catppuccin.tmux";

  cpuScript = "${pkgs.tmuxPlugins.cpu}/share/tmux-plugins/cpu/cpu.tmux";

  # Continuum refuses to auto-save/auto-restore when it sees a second tmux
  # server on the machine, and tmux-toggle-popup's durable popups run on a
  # dedicated "-L popup" server, so the stock plugin silently disables itself
  # here. We only ever run one real server per machine, so drop the guard
  # (and an accidental upstream "set -x" debug trace).
  continuum = pkgs.tmuxPlugins.continuum.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      sed -i -e '/^set -x$/d' \
             -e 's/if ! another_tmux_server_running; then/if true; then/' continuum.tmux
      sed -i 's/^another_tmux_server_running_on_startup() {/&\n\treturn 1/' scripts/helpers.sh
    '';
  });

  continuumScript = "${continuum}/share/tmux-plugins/continuum/continuum.tmux";

  # Resurrect restores remote-connection panes by re-running their saved
  # command line, which works for ssh but not for mosh: the pane process is
  # "mosh-client <ip> <port>" with a one-time key, so replaying it can never
  # reconnect. Connecting through this wrapper keeps a replayable argv
  # ("mssh host ...") in the pane instead.
  mssh = pkgs.writeShellScriptBin "mssh" ''
    exec mosh "$@"
  '';
in
{
  home.packages = [ mssh ];

  programs.tmux = {
    enable = true;
    baseIndex = 1;

    # catppuccin and cpu are intentionally NOT in this list: they must run
    # after the @catppuccin_* options set in tmux.conf, so they are sourced
    # manually at the end of extraConfig instead (the store paths below keep
    # the plugin packages in the closure). Listing them here as well would
    # load each of them twice.
    plugins = with pkgs.tmuxPlugins; [
      vim-tmux-navigator
      tmux-toggle-popup
      resurrect
    ];

    # continuum is sourced last on purpose: it prepends its (invisible)
    # autosave hook to whatever status-right holds at that point, so every
    # "set -g status-right" and the catppuccin/cpu scripts must already have
    # run — a later overwrite of status-right would silently kill autosave.
    extraConfig = builtins.readFile ../../files/tmux/tmux.conf + ''
      run-shell ${cpuScript}
      run-shell ${catppuccinScript}
      run-shell ${continuumScript}
    '';
  };
}
