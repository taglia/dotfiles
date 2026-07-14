{ lib, ... }:

{
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.starship = {
    enable = true;
  };

  programs.atuin = {
    enable = true;

    settings = {
      auto_sync = lib.mkDefault false;
      update_check = false;
      enter_accept = true;
      # sync_frequency = "5m";
    };
  };

  programs.mise = {
    enable = true;

    enableFishIntegration = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  programs.btop.enable = true;
  programs.htop.enable = true;

  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
  };

  programs.bat.enable = true;
}
