{
  inputs,
  lib,
  pkgs,
  ...
}:

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

    # Stable nixpkgs currently carries a mise release from before the native
    # minimum_release_age setting. Use the already-locked unstable input until
    # the next stable release contains that support.
    package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mise;

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
