# Terminal chat: nchat (WhatsApp + Telegram) and discordo (Discord).
#
# Packages only, deliberately: neither tool needs anything committed here.
# Credentials and session state are created at runtime in the home directory
# — nchat keeps its sessions under ~/.config/nchat, discordo stores the
# Discord token in the macOS Keychain (go-keyring) — so, unlike aerc, there
# is no accounts file to encrypt and no agenix wiring.
#
# First-run setup:
#
#   nchat -s      setup wizard. WhatsApp pairs by QR code as a linked device
#                 (whatsmeow, the same multi-device protocol as WhatsApp
#                 Web); Telegram logs in by phone number (tdlib, Telegram's
#                 own client library — third-party clients are sanctioned).
#                 Keys are remappable in ~/.config/nchat/key.conf (chord
#                 style, not modal).
#
#   discordo      prompts for a user token on first run, then keeps it in
#                 the Keychain. Vim-style j/k/g/G bindings by default. Note
#                 that third-party clients are against Discord's ToS
#                 (accepted trade-off; ban risk is real). Its config.toml is
#                 declared below (theme only; keybind overrides belong there
#                 too) — discordo never writes it, and merges it over its
#                 built-in defaults, so declaring just the theme keys leaves
#                 every other setting at its default.
#
# nchat rewrites its config files on exit, but Config::Save silently no-ops
# when the file is not writable (verified in lib/ncutil/src/config.cpp), so
# the read-only theme symlinks and the partial ui.conf below are safe —
# same situation as chess-tui in entertainment.nix. Declared conf files
# only need the settings that differ: defaults load first and the file
# overlays them. The cost is that in-UI changes to *declared* files no
# longer persist across restarts; key.conf and app.conf stay unmanaged, so
# nchat still owns those. Fold anything worth keeping back into this module.
#
# Caveat, verified in the nchat 5.16.9 source: WhatsApp's chat lock is not
# honored. Locked chats arrive in history sync flagged `locked`, but nchat's
# gowm.go never reads that flag, so they show up as ordinary fully-readable
# chats. The terminal session is the only privacy boundary.
{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # nchat comes from unstable, not the pinned stable nixpkgs: WhatsApp's
  # servers enforce a minimum client version and reject older whatsmeow
  # builds with "WhatsApp client is outdated" (see nchat's WMOUTDATED.md),
  # so nchat has to track upstream releases closely. Reuses the flake's
  # shared unstable evaluation, same as the ai.nix profile's tools.
  nchat = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.nchat;

  inherit ((import ../../lib/catppuccin.nix).palette)
    blue
    green
    yellow
    red
    peach
    overlay0
    ;

  # Theme files come from nchat's source tree, not the package output: the
  # unstable package (unlike stable 5.14.44) no longer installs
  # share/nchat/themes at all, which left the previous package-path symlinks
  # dangling. src is a store path, so this still tracks the installed
  # version.
  nchatThemeDir = "${nchat.src}/themes/catppuccin-mocha";

  # The shipped catppuccin-mocha theme colors unread chats identically to
  # read ones (list_color_unread_fg = list_color_fg = subtext1), leaving the
  # right-edge "*" as the only unread cue. Rebuild color.conf with unread in
  # peach (matching aerc's accent choices); the grep guard fails the build
  # if a theme update changes that line instead of silently dropping the
  # patch, like the aerc binds.conf in mail.nix.
  nchatColorConf = pkgs.runCommand "nchat-color.conf" { } ''
    stock=${nchatThemeDir}/color.conf
    grep -qxF 'list_color_unread_fg=0xbac2de' "$stock"
    sed 's/^list_color_unread_fg=0xbac2de$/list_color_unread_fg=0x${peach}/' "$stock" > $out
  '';

  # Catppuccin Mocha accents (shared palette, lib/catppuccin.nix) over
  # discordo's stock theme: blue replaces green as the "active" accent, and
  # presence/message colors get their Mocha equivalents. Only these keys are
  # overridden; attributes are restated where present because a style table
  # replaces the whole default style, not individual fields.
  discordoConfig = ''
    [theme.title]
    active_style = { foreground = "#${blue}", attributes = "bold" }

    [theme.footer]
    active_style = { foreground = "#${blue}", attributes = "bold" }

    [theme.border]
    active_style = { foreground = "#${blue}", attributes = "bold" }

    [theme.guilds_tree]
    online_style = { foreground = "#${green}" }
    idle_style = { foreground = "#${yellow}" }
    dnd_style = { foreground = "#${red}" }
    offline_style = { foreground = "#${overlay0}" }

    [theme.messages_list]
    mention_style = { foreground = "#${blue}", attributes = "bold" }
    emoji_style = { foreground = "#${green}" }
    url_style = { foreground = "#${blue}" }
    attachment_style = { foreground = "#${yellow}" }

    [theme.messages_list.embeds]
    title_style = { foreground = "#${blue}", attributes = "bold" }
    url_style = { foreground = "#${blue}", underline = "solid" }
  '';
in
{
  home.packages = [
    nchat
    pkgs.discordo
  ];

  # discordo resolves its config via Go's os.UserConfigDir, which on macOS is
  # ~/Library/Application Support (XDG is ignored there). Deploy to the path
  # the host actually reads, like chess-tui in entertainment.nix.
  xdg.configFile."discordo/config.toml" = lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin) {
    text = discordoConfig;
  };
  home.file."Library/Application Support/discordo/config.toml" =
    lib.mkIf pkgs.stdenv.hostPlatform.isDarwin
      {
        text = discordoConfig;
      };

  # Wider chat list (default 14 columns is too narrow for full chat names).
  # The in-UI resize keys (alt-, / alt-.) collide with macOS, hence declared
  # here; all other ui.conf settings keep their built-in defaults. force,
  # because nchat has already written its own ui.conf on first run and the
  # switch must replace it (like the chess-tui config in entertainment.nix).
  xdg.configFile."nchat/ui.conf" = {
    text = ''
      list_width=30
    '';
    force = true;
  };

  # Catppuccin Mocha, from the theme files in nchat's own tree (a theme is
  # exactly these two files copied into ~/.config/nchat); color.conf carries
  # the unread patch above.
  xdg.configFile."nchat/color.conf".source = nchatColorConf;
  xdg.configFile."nchat/usercolor.conf".source = "${nchatThemeDir}/usercolor.conf";
}
