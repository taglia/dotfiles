{ pkgs, ... }:

let
  catppuccinScript = "${pkgs.tmuxPlugins.catppuccin}/share/tmux-plugins/catppuccin/catppuccin.tmux";

  cpuScript = "${pkgs.tmuxPlugins.cpu}/share/tmux-plugins/cpu/cpu.tmux";
in
{
  programs.tmux = {
    enable = true;

    # catppuccin and cpu are intentionally NOT in this list: they must run
    # after the @catppuccin_* options set in tmux.conf, so they are sourced
    # manually at the end of extraConfig instead (the store paths below keep
    # the plugin packages in the closure). Listing them here as well would
    # load each of them twice.
    plugins = with pkgs.tmuxPlugins; [
      sensible
      resurrect
      continuum
      copycat
      yank
      vim-tmux-navigator
      tmux-toggle-popup
    ];

    extraConfig = builtins.readFile ../../files/tmux/tmux.conf + ''
      run-shell ${cpuScript}
      run-shell ${catppuccinScript}
    '';
  };
}
