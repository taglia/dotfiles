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
      autoUpdate = false;
      upgrade = false;
      cleanup = "zap";
      # Homebrew Bundle 4.7 requires an explicit noninteractive confirmation
      # when `--cleanup` is used during activation.
      extraFlags = [ "--force-cleanup" ];
    };

    taps = [
      # "marsanne/cask" # This is the licensed version of Cork (GUI for brew)
      "kitknox/rootshell" # rootshell terminal; cask trusted individually below (not whole-tap)

    ];

    brews = [
      "mas" # Required for `homebrew.masApps`.
      "mole"
    ];

    # Keep alphabetically sorted so diffs stay reviewable: with
    # `cleanup = "zap"` an accidentally dropped entry uninstalls the app.
    casks = [
      "1password"
      "1password-cli"
      "a-better-finder-rename"
      "acorn"
      "affinity"
      "airbuddy"
      "airfoil"
      "aldente"
      "alfred"
      "arduino-ide"
      "audio-hijack"
      "balenaetcher"
      "bambu-studio"
      "bbedit"
      "big-mean-folder-machine"
      "blender"
      "blockblock"
      "brave-browser"
      "calibre"
      "carbon-copy-cloner"
      "cheetah3d"
      "chronosync"
      "coconutbattery"
      "cookie"
      "cryptomator"
      "cyberduck"
      "daisydisk"
      "default-folder-x"
      "devonthink"
      "downie"
      "duckduckgo"
      "fantastical"
      "ferdium"
      "fission"
      "ghostty"
      "google-chrome"
      "gpg-suite"
      "hazel"
      "homerow"
      "hyperbackupexplorer"
      "imazing"
      "jordanbaird-ice@beta"
      "keyboard-maestro"
      "kitty"
      "knockknock"
      "linearmouse"
      "lingon-x"
      "little-snitch"
      "loopback"
      "moonlight"
      "mountain-duck"
      "mouseless@preview"
      "murus"
      "obsidian"
      "onlyoffice"
      "orion"
      "pacifist"
      "permute"
      "portfolioperformance"
      "proton-drive"
      "protonvpn"
      "qflipper"
      "raspberry-pi-imager"
      "raycast"
      "rhino-app"
      {
        name = "kitknox/rootshell/rootshell"; # fully-qualified => trust applies to this cask only
      }
      "screenflow"
      "sf-symbols"
      "signal"
      "soundsource"
      "spamsieve"
      "tailscale-app"
      "threema@beta"
      "trader-workstation"
      "trezor-suite"
      "utm"
      "virtualhereserver"
      "vlc"
      "yubico-authenticator"
    ];

    # Mac App Store apps use Homebrew Bundle's `mas` support.
    #
    # Requirements:
    # - The Mac must be signed into the App Store with an Apple ID that owns
    #   these apps.
    # - Keep this list complete when `cleanup = "zap"` is enabled, because
    #   Homebrew Bundle cleanup can remove undeclared MAS apps and related
    #   support files where Homebrew supports zapping.
    masApps = {
      "1Blocker" = 1365531024;
      "1Password for Safari" = 1569813296;
      "About by PCalc" = 1613982997;
      "Actions For Obsidian" = 1659667937;
      "AutoMounter" = 1160435653;
      "Blackmagic Disk Speed Test" = 425264550;
      "Dato" = 1470584107;
      "DaVinci Resolve" = 571213070;
      "Drafts" = 1435957248;
      "DS Manager / NAS Pro" = 1435876433;
      "Due" = 524373870;
      "Endurance" = 1590043284;
      "GarageBand" = 682658836;
      "HazeOver" = 430798174;
      "Hush" = 1544743900;
      "iA Writer" = 775737590;
      "iMovie" = 408981434;
      "Infuse" = 1136220934;
      "Internet Access Policy Viewer" = 1482630322;
      "Jayson" = 1468691718;
      "Just Press Record" = 1033342465;
      "Kagi for Safari" = 1622835804;
      "Keynote" = 361285480;
      "lire" = 1482527526;
      "Mactracker" = 430255202;
      "Marked 3" = 6747497179;
      "Metapho" = 914457352;
      "Momentum" = 1564329434;
      "Noir" = 1592917505;
      "Numbers" = 361304891;
      "Obsidian Web Clipper" = 6720708363;
      "OmniFocus 4" = 1542143627;
      "OmniGraffle 7" = 1142578753;
      "OmniPlan 4" = 1460319993;
      "Overlap" = 1516950324;
      "Pages" = 361309726;
      "Parcel" = 375589283;
      "PCalc" = 403504866;
      "PiPifier" = 1160374471;
      "Raycast Companion" = 6738274497;
      "Save to Reader" = 1640236961;
      "Screens 5" = 1663047912;
      "ScreenFloat" = 414528154;
      "Secure ShellFish" = 1336634154;
      "Shapr3D" = 1091675654;
      "SponsorBlock for Safari" = 1573461917;
      "StopTheMadness Pro" = 6471380298;
      "TestFlight" = 899247664;
      "TrashMe 3" = 1490879410;
      "WaterMinder" = 1415257369;
      "Windows App" = 1295203466;
      "Yoink" = 457622435;
      "Amazon Kindle: Reading App" = 302584613;
    };
  };
}
