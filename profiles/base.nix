{
  config,
  inputs,
  ...
}:

{
  imports = [
    ../modules/home/cli-tools.nix
    ../modules/home/fish.nix
    ../modules/home/packages-cli.nix
    ../modules/home/shells.nix
    ../modules/home/tmux.nix
    ../modules/home/xdg-files.nix
  ];

  # nh wraps darwin-rebuild / home-manager with a package diff before each
  # switch and a unified `nh clean`. `flake` sets the default target so plain
  # `nh darwin switch` / `nh home switch` work from anywhere.
  programs.nh = {
    enable = true;
    flake = "${config.home.homeDirectory}/dotfiles";
  };

  # Avoid Home Manager's generated option manual, which can trigger
  # context warnings for options.json on newer Nix versions.
  manual.manpages.enable = false;

  nix.registry = {
    n.to = {
      type = "path";
      path = inputs.nixpkgs;
    };
    u.to = {
      type = "path";
      path = inputs.nixpkgs-unstable;
    };
  };

  programs.nix-index = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };

  programs.nix-index-database.comma.enable = true;
}
