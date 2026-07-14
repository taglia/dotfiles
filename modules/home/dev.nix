{
  lib,
  user,
  ...
}:

{
  imports = [
    ./vim/default.nix
  ];

  home.sessionVariables = {
    EDITOR = lib.mkForce "nvim";
    VISUAL = lib.mkForce "nvim";
  };

  # Shared by bash, zsh and fish; the mkForce entries override the vim
  # aliases from modules/home/shells.nix on dev hosts.
  home.shellAliases = {
    gs = "git status";
    gc = "git commit";
    gp = "git push";
    gl = "git pull";
    vi = lib.mkForce "nvim";
    vim = lib.mkForce "nvim";
    vimdiff = lib.mkForce "nvim -d";
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  programs.git = {
    enable = true;

    settings.user.name = user.githubUsername;
    settings.user.email = user.email;
  };
}
