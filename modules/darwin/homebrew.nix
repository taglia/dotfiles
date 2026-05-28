{ ... }:

{
  # nix-darwin generates a Brewfile from this module and runs `brew bundle`
  # during `darwin-rebuild switch`.
  #
  # Homebrew package versions are not pinned by flake.lock. Formulae, casks,
  # and Mac App Store apps come from the Homebrew/App Store metadata available
  # on the machine at activation time.
  homebrew = {
    enable = true;

    onActivation = {
      # Keep the current manual `brew update` workflow during migration.
      autoUpdate = false;

      # Do not upgrade installed brews, casks, or MAS apps during activation.
      upgrade = false;

      # Do not remove unmanaged Homebrew items while the list is being tested.
      cleanup = "none";
    };

    brews = [
      "mas" # Required for `homebrew.masApps`.
      "mole"
    ];

    # Current casks from `brew list --cask`.
    casks = [
      "1password-cli"
      "aerospace"
      "arduino-ide"
      "balenaetcher"
      "basictex"
      "big-mean-folder-machine"
      "blender"
      "cork"
      "downie"
      "ferdium"
      "font-hack-nerd-font"
      "font-iosevka-nerd-font"
      "google-chrome"
      "jordanbaird-ice@beta"
      "kitty"
      "lingon-x"
      "mailmate"
      "mouseless@preview"
      "murus"
      "onlyoffice"
      "pacifist"
      "permute"
      "qflipper"
      "rhino-app"
      "script-debugger"
      "threema@beta"
      "virtualhereserver"
      "yubico-authenticator"
    ];

    # Mac App Store apps use Homebrew Bundle's `mas` support.
    #
    # Requirements:
    # - The Mac must be signed into the App Store with an Apple ID that owns
    #   these apps.
    # - Removing an entry here does not uninstall the app; Homebrew Bundle does
    #   not support MAS cleanup.
    masApps = {
      "OmniFocus 4" = 1542143627;
      "Secure ShellFish" = 1336634154;
    };
  };
}
