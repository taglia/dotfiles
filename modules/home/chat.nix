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
# read-only theme symlinks below are safe — same situation as chess-tui in
# entertainment.nix. The other conf files (ui.conf, key.conf, app.conf) are
# left to nchat so in-UI setting changes persist; fold anything worth
# keeping back into this module.
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
    overlay0
    ;

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

  # Catppuccin Mocha, from the theme files nchat ships itself (a theme is
  # exactly these two files copied into ~/.config/nchat) — sourced from the
  # package so they track the installed version.
  xdg.configFile."nchat/color.conf".source =
    "${nchat}/share/nchat/themes/catppuccin-mocha/color.conf";
  xdg.configFile."nchat/usercolor.conf".source =
    "${nchat}/share/nchat/themes/catppuccin-mocha/usercolor.conf";
}
