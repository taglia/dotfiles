{ pkgs, ... }:

{
  # GUI workstation stack. Imported by machines that want a desktop; headless
  # hosts simply leave this module out.

  # System-level GUI apps. Kept here rather than base.nix so headless NixOS
  # hosts don't pull a GPU terminal. `ghostty` builds from source (Zig) and is
  # supported on aarch64-linux and x86_64-linux; the first build is slow, later
  # builds are cached. The macOS code-signing problem that affects `ghostty-bin`
  # is a Darwin-only issue and does not apply here.
  environment.systemPackages = with pkgs; [
    ghostty
    vivaldi
    librewolf
  ];

  # Iosevka + Hack Nerd Fonts, matching the terminal/editor fonts used on
  # darwin (see lib/fonts.nix, shared with modules/darwin/packages.nix).
  fonts.packages = import ../../lib/fonts.nix pkgs;

  services.xserver.enable = true;

  # GNOME via GDM. These are the 26.05 option paths (moved out of the
  # services.xserver.* namespace in earlier releases).
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # NetworkManager suits interactive desktops/laptops (servers usually prefer
  # systemd-networkd, so this is intentionally not in base.nix).
  networking.networkmanager.enable = true;

  services.printing.enable = true;

  # Audio via PipeWire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  programs.firefox.enable = true;

  # macOS-style natural (reverse) scrolling on the trackpad. Kept in the
  # shared desktop module so every NixOS host with GNOME gets it as a default;
  # the user can still override it from GNOME Settings.
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/desktop/peripherals/touchpad" = {
          natural-scroll = true;
        };
      };
    }
  ];
}
