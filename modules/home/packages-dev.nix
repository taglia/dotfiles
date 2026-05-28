{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # General development tools
    fx
    gitleaks
    glow
    sqlite
    nmap
    hdf5
    hugo
    hub
    links2
    mosh
    pandoc
    pwgen
    sc-im
    tabiew
    unar

    # Nix formatting
    nixfmt
  ];
}
