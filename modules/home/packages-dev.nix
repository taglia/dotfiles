{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # General development tools
    colima
    docker-client
    docker-compose
    fx
    gitleaks
    glow
    lima
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
    shellcheck
    tabiew
    unar

    # Nix formatting
    nixfmt

    # TeX
    texlive.combined.scheme-small
  ];
}
