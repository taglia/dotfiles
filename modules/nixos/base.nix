{
  pkgs,
  user,
  ...
}:

{
  # Generic settings shared by every NixOS machine (VM or physical). Anything
  # here should make sense on a headless box too — desktop bits live in
  # desktop.nix, guest/VM bits in qemu-guest.nix.

  # Flakes everywhere. This was missing from the Calamares-generated config and
  # is required for `nixos-rebuild --flake`.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;

  # Login shell across all machines; pairs with the Home Manager fish config.
  # Enabling it system-wide also installs vendor completions and registers fish
  # as a valid login shell (required before setting it as a user's shell).
  programs.fish.enable = true;

  # A real editor at the system level — for root, recovery, and `sudoedit` —
  # so you're never dropped into nano. Your personal, fully-configured nvim
  # still comes from Home Manager for your own user.
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  # Mosh server on every NixOS host. This installs mosh system-wide and (via
  # the module's default openFirewall = true) opens UDP 60000-61000, the range
  # mosh-server picks its per-session port from. The initial handshake still
  # goes over regular SSH (TCP 22).
  programs.mosh.enable = true;

  environment.systemPackages = with pkgs; [
    git # needed by `nixos-rebuild --flake` against a git tree
    ghostty.terminfo
  ];

  # Locale and time. Override per-host if a machine lives elsewhere.
  time.timeZone = "Asia/Singapore";
  i18n.defaultLocale = "en_SG.UTF-8";

  # glibc only has the locales we generate. en_US is needed because the Home
  # Manager shells set LANG=en_US.UTF-8 (deliberately no LC_ALL, see
  # modules/home/shells.nix); en_SG is the system default; C.UTF-8 is the
  # always-safe fallback. Without en_US you'd get "cannot change locale"
  # warnings from that LANG.
  i18n.supportedLocales = [
    "C.UTF-8/UTF-8"
    "en_US.UTF-8/UTF-8"
    "en_SG.UTF-8/UTF-8"
  ];
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_SG.UTF-8";
    LC_IDENTIFICATION = "en_SG.UTF-8";
    LC_MEASUREMENT = "en_SG.UTF-8";
    LC_MONETARY = "en_SG.UTF-8";
    LC_NAME = "en_SG.UTF-8";
    LC_NUMERIC = "en_SG.UTF-8";
    LC_PAPER = "en_SG.UTF-8";
    LC_TELEPHONE = "en_SG.UTF-8";
    LC_TIME = "en_SG.UTF-8";
  };
  console.keyMap = "us";

  # Primary user, shared across machines. Set the login shell to fish here so it
  # matches the Home Manager configuration.
  users.users.${user.username} = {
    isNormalUser = true;
    description = user.username;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.fish;
  };
  # Passwordless sudo for wheel — convenient on personal machines/VMs.
  security.sudo.wheelNeedsPassword = false;
}
