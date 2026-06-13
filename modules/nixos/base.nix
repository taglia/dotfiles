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

  environment.systemPackages = with pkgs; [
    git # needed by `nixos-rebuild --flake` against a git tree
  ];

  # Locale and time. Override per-host if a machine lives elsewhere.
  time.timeZone = "Asia/Singapore";
  i18n.defaultLocale = "en_SG.UTF-8";
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
}
