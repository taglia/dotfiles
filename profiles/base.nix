{
  ...
}:

{
  imports = [
    ../modules/packages-cli.nix
    ../modules/shells.nix
    ../modules/tmux.nix
  ];

  # Avoid Home Manager's generated option manual, which can trigger
  # context warnings for options.json on newer Nix versions.
  manual.manpages.enable = false;
}
