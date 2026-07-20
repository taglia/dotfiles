{
  config,
  pkgs,
  ...
}:

let
  vim = "${pkgs.vim}/bin/vim";
in
{
  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = vim;
    VISUAL = vim;
    LANG = "en_US.UTF-8";
    # Intentionally no LC_ALL: it overrides every per-category LC_* setting
    # (e.g. NixOS's en_SG formatting for time/paper/measurement). LANG alone is
    # the fallback for any category the system doesn't set, so this keeps US
    # English messages while letting system locale settings apply.
    XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
  };

  # Shared by bash, zsh and fish.
  home.shellAliases = {
    ll = "ls -la";
    la = "ls -A";
    l = "ls -CF";

    vi = vim;
    inherit vim;
    vimdiff = "${vim} -d";
  };

  programs.bash.enable = true;

  programs.zsh.enable = true;
}
