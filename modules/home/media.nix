{ pkgs, ... }:

{
  home.packages = with pkgs; [
    ffmpeg
    imagemagick

    asciiquarium
    cmatrix
    nethack
  ];
}
