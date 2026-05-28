{
  ...
}:

{
  imports = [
    ../modules/home/packages-cli.nix
    ../modules/home/shells.nix
    ../modules/home/tmux.nix
  ];

  # Avoid Home Manager's generated option manual, which can trigger
  # context warnings for options.json on newer Nix versions.
  manual.manpages.enable = false;
}
