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
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };

    taps = [
      "marsanne/cask"
      "tw93/tap"
      "1password/tap"
    ];

    brews = [
      "mas" # Required for `homebrew.masApps`.
      "mole"
    ];

    # Current casks from `brew list --cask`.
    casks = [
      "1password"
      "1password-cli"
      "a-better-finder-rename"
      "affinity"
      "airbuddy"
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
      "mouseless@preview"
      "murus"
      "onlyoffice"
      "pacifist"
      "permute"
      "qflipper"
      "rhino-app"
      "threema@beta"
      "virtualhereserver"
      "yubico-authenticator"

      "brave-browser"
      "cyberduck"
      "obsidian"
      "ollama-app"
      "knockknock"
      "ghostty"
      "stats"
      "signal"
      "protonvpn"
      "proton-drive"
      "portfolioperformance"
      "raycast"
      "soundsource"
      "linearmouse"
      "homerow"
      "hazel"
      "gpg-suite"
      "daisydisk"
      "coconutbattery"
      "bbedit"
      "duckduckgo"
      "aldente"
      "keyboard-maestro"
      "cryptomator"
      "mountain-duck"
      "cyberduck"
      "orion"
      "blockblock"
      "audio-hijack"
      "moonlight"
      "little-snitch"
      "raspberry-pi-imager"
      "alfred"
      "airfoil"
      "acorn"
      "cheetah3d"
      "chronosync"
      "default-folder-x"
      "fission"
      "hyperbackupexplorer"
      "loopback"
      "screenflow"
      "sf-symbols"
      "spamsieve"
      "vlc"
    ];

    # Mac App Store apps use Homebrew Bundle's `mas` support.
    #
    # Requirements:
    # - The Mac must be signed into the App Store with an Apple ID that owns
    #   these apps.
    # - Keep this list complete when `cleanup = "uninstall"` is enabled, because
    #   Homebrew Bundle cleanup can remove undeclared MAS apps.
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
      "Tailscale" = 1475387142;
      "TestFlight" = 899247664;
      "TrashMe 3" = 1490879410;
      "WaterMinder" = 1415257369;
      "Windows App" = 1295203466;
      "Yoink" = 457622435;
    };
  };
}
