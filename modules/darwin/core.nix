# Baseline nix-darwin configuration shared by every Darwin host: nix daemon
# settings, GC, the Linux remote builder, shells and the primary user. Host
# lists and Home Manager wiring stay in flake.nix.
{
  pkgs,
  inputs,
  user,
  ...
}:

{
  system.stateVersion = 6;
  system.primaryUser = user.username;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Lightweight NixOS VM used as a Linux remote builder, so the
  # Linux homeConfigurations (and any Linux package) can be built
  # and tested from this Mac. Provides aarch64-linux natively. To
  # also build x86_64-linux, add emulation (slower) with:
  #   nix.linux-builder.config.boot.binfmt.emulatedSystems = [ "x86_64-linux" ];
  nix.linux-builder.enable = true;
  # The build user must be trusted to use the remote builder.
  nix.settings.trusted-users = [ "@admin" ];

  # Hard-link identical files in the store and collect old
  # generations weekly. Complements scripts/gc.sh, which also
  # prunes Homebrew; this keeps the Nix store tidy without it.
  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    interval = {
      Weekday = 0;
      Hour = 3;
      Minute = 0;
    };
    options = "--delete-older-than 30d";
  };

  programs.fish.enable = true;

  security.pam.services.sudo_local = {
    # Use Touch ID and Apple Watch for sudo when macOS allows it.
    touchIdAuth = true;

    # Keep biometric sudo working from inside tmux/screen sessions.
    reattach = true;
  };

  environment.shells = [
    pkgs.bashInteractive
    pkgs.fish
    pkgs.zsh
  ];

  environment.systemPackages = [
    inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.home-manager
  ];

  users.users.${user.username} = {
    home = "/Users/${user.username}";
  };

  # Keep the primary user's login shell on the stable nix-darwin
  # system profile path. The old standalone Home Manager path
  # under ~/.nix-profile can disappear once Home Manager is
  # integrated into nix-darwin.
  system.activationScripts.primaryUserShell.text = ''
    dscl . -create /Users/${user.username} UserShell /run/current-system/sw/bin/fish
  '';
}
