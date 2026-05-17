{ lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    ffmpeg
    imagemagick
    qemu
  ];

  programs.bash.initExtra = lib.mkAfter ''
    if [ -d /opt/homebrew/bin ]; then
      case ":$PATH:" in
        *:/opt/homebrew/bin:*) ;;
        *) PATH="$PATH:/opt/homebrew/bin" ;;
      esac
    fi

    if [ -d /opt/homebrew/sbin ]; then
      case ":$PATH:" in
        *:/opt/homebrew/sbin:*) ;;
        *) PATH="$PATH:/opt/homebrew/sbin" ;;
      esac
    fi
  '';

  programs.zsh.initContent = lib.mkAfter ''
    if [[ -d /opt/homebrew/bin && ":$PATH:" != *":/opt/homebrew/bin:"* ]]; then
      path+=("/opt/homebrew/bin")
    fi

    if [[ -d /opt/homebrew/sbin && ":$PATH:" != *":/opt/homebrew/sbin:"* ]]; then
      path+=("/opt/homebrew/sbin")
    fi
  '';

  programs.fish.shellInit = lib.mkAfter ''
    fish_add_path --move --append --path \
        /opt/homebrew/bin \
        /opt/homebrew/sbin
  '';
}
