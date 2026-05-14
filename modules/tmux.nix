{ pkgs, ... }:

let
  catppuccinScript =
    "${pkgs.tmuxPlugins.catppuccin}/share/tmux-plugins/catppuccin/catppuccin.tmux";

  cpuScript =
    "${pkgs.tmuxPlugins.cpu}/share/tmux-plugins/cpu/cpu.tmux";

  batteryScript =
    "${pkgs.tmuxPlugins.battery}/share/tmux-plugins/battery/battery.tmux";
in
{
  programs.tmux = {
    enable = true;

    plugins = with pkgs.tmuxPlugins; [
      sensible
      resurrect
      continuum
      copycat
      yank
      cpu
      battery
      vim-tmux-navigator
      catppuccin
    ];

    extraConfig =
      builtins.readFile ../files/tmux.conf
      + ''
        run-shell ${cpuScript}
        run-shell ${batteryScript}
        run-shell ${catppuccinScript}
      '';
  };
}

