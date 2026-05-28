{
  config,
  lib,
  user,
  ...
}:

let
  nvim = "${config.programs.nixvim.build.package}/bin/nvim";

  shellAliases = {
    gs = "git status";
    gc = "git commit";
    gp = "git push";
    gl = "git pull";
    nvim = nvim;
    vi = lib.mkForce nvim;
    vim = lib.mkForce nvim;
    vimdiff = lib.mkForce "${nvim} -d";
  };
in

{
  imports = [
    ./vim/default.nix
  ];

  home.sessionVariables = {
    EDITOR = lib.mkForce nvim;
    VISUAL = lib.mkForce nvim;
  };

  programs.bash.shellAliases = shellAliases;
  programs.zsh.shellAliases = shellAliases;
  programs.fish.shellAliases = shellAliases;

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
