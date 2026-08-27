# Terminal email: aerc over IMAP.
#
# Split deliberately in two, because this repo is public:
#
#   - aerc.conf and the styleset (nothing personal) are declared here.
#   - accounts.conf — account names, addresses, usernames, servers AND app
#     passwords — is a single agenix secret deployed whole to
#     ~/.config/aerc/accounts.conf, the same pattern as ssh-config.age.
#     Nothing account-related appears in the repo or the Nix store; the
#     decrypted file is 0400, which also satisfies aerc's permission check
#     on accounts.conf (so no unsafe-accounts-conf waiver is needed).
#
# Edit accounts with `agenix -e secrets/mail-accounts.age`, then rebuild
# (the agenix activation re-decrypts on switch). aerc-accounts(5) documents
# the format; a neutral template:
#
#   [account-name]
#   from = First Last <you@example.com>
#   source = imaps://you%40example.com:app-password@imap.example.com:993
#   outgoing = smtps+plain://you%40example.com:app-password@smtp.example.com:465
#   default = INBOX
#   copy-to = Sent            # omit for Gmail: it files sent mail itself
#   postpone = Drafts
#   cache-headers = true
#
# URL-encode '@' in the username as %40 (app passwords from Google/Apple/
# Yahoo are URL-safe as issued). Common servers: Gmail imap.gmail.com:993 /
# smtp.gmail.com:465 (archive = [Gmail]/All Mail, postpone = [Gmail]/Drafts);
# iCloud imap.mail.me.com:993 / smtp.mail.me.com:587 with `smtp+plain://`
# (STARTTLS) and copy-to = Sent Messages; Yahoo imap.mail.yahoo.com:993 /
# smtp.mail.yahoo.com:465.
#
# Exchange Online / Microsoft 365 tenants (universities, employers) have no
# app passwords: IMAP works only with OAuth2, and only if the tenant leaves
# IMAP enabled. Route 1: a token helper (pkgs.oama or pkgs.pizauth) keeps a
# refresh token, and the account uses
#   source = imaps+xoauth2://you%40example.edu@outlook.office365.com:993
#   source-cred-cmd = oama access you@example.edu
# (same idea for outgoing = smtp+xoauth2://...@smtp.office365.com:587); the
# helper needs a client id the tenant trusts — Thunderbird's
# (9e5f94bc-e8a4-4e73-b8be-63364c29d753) usually is. Route 2, if IMAP is
# disabled: run DavMail (pkgs.davmail) as a local EWS/OWA-to-IMAP bridge and
# point a plain localhost IMAP account at it.
{
  config,
  pkgs,
  ...
}:

let
  inherit ((import ../../lib/catppuccin.nix).palette)
    text
    subtext1
    overlay1
    overlay0
    surface1
    surface0
    mantle
    blue
    red
    yellow
    green
    peach
    ;
in
{
  # Home Manager's aerc module writes its config to ~/Library/Preferences on
  # Darwin unless xdg.enable is set, while aerc itself follows the exported
  # XDG_CONFIG_HOME (shells.nix) and would read an empty ~/.config/aerc.
  # Enabling xdg changes nothing else here: the xdg.*Home defaults equal the
  # paths this repo already uses (the duplicate XDG_CONFIG_HOME definition
  # merges because the values are identical, and the other XDG_* variables
  # get their conventional defaults), and no other imported HM module
  # branches on xdg.enable.
  xdg.enable = true;

  # Keybindings: aerc ignores its built-in binds.conf entirely once a user
  # one exists (no merging), so the file is generated from the stock binds
  # plus vim-style tab keys, at build time rather than via
  # programs.aerc.extraBinds (which would ship only the extra lines and lose
  # every default). Changes vs stock: `gg` selects the top of the message
  # list (was `g`, freeing it up as a prefix), `gt`/`gT` cycle the account
  # tabs like vim tab pages (stock `<C-n>`/`<C-p>` and `]t`/`[t` still
  # work). The grep guard fails the build if an aerc update changes the
  # rebound line, instead of silently dropping the remap.
  xdg.configFile."aerc/binds.conf".source = pkgs.runCommand "aerc-binds.conf" { } ''
    stock=${config.programs.aerc.package}/share/aerc/binds.conf
    grep -qxF 'g = :select 0<Enter>' "$stock"
    {
      printf '%s\n' 'gt = :next-tab<Enter>' 'gT = :prev-tab<Enter>'
      sed 's/^g = :select 0<Enter>$/gg = :select 0<Enter>/' "$stock"
    } > $out
  '';

  programs.aerc = {
    enable = true;

    extraConfig = {
      ui = {
        threading-enabled = true;
        mouse-enabled = true;
        # Folder sidebar as a tree — nicer with several accounts' [Gmail]/…
        # style hierarchies.
        dirlist-tree = true;
        styleset-name = "catppuccin-mocha";
      };

      # Everything renders as text. `html` is aerc's bundled filter, which
      # nixpkgs wraps with w3m + dante: HTML is dumped to plain text through
      # w3m, network-isolated via socksify so remote content (tracking
      # pixels, images) is never fetched. Non-text parts are not rendered at
      # all — they show as attachment entries to :save / :open explicitly.
      filters = {
        "text/plain" = "colorize";
        "text/html" = "html | colorize";
        "text/calendar" = "calendar";
        "message/delivery-status" = "colorize";
        "message/rfc822" = "colorize";
        ".headers" = "colorize";
      };
    };

    # Minimal Catppuccin Mocha accents over the terminal's own background,
    # from the shared palette (lib/catppuccin.nix). See aerc-stylesets(7).
    stylesets."catppuccin-mocha".global = {
      "*.default" = true;
      "*.selected.reverse" = "toggle";
      "default.fg" = "#${text}";
      "error.fg" = "#${red}";
      "warning.fg" = "#${yellow}";
      "success.fg" = "#${green}";
      "title.fg" = "#${blue}";
      "title.bold" = true;
      "header.fg" = "#${blue}";
      "header.bold" = true;
      "statusline_default.fg" = "#${subtext1}";
      "statusline_default.bg" = "#${surface0}";
      "statusline_error.fg" = "#${red}";
      "statusline_success.fg" = "#${green}";
      "msglist_unread.bold" = true;
      "msglist_flagged.fg" = "#${yellow}";
      "msglist_deleted.fg" = "#${overlay0}";
      "msglist_marked.bg" = "#${surface1}";
      "msglist_result.fg" = "#${peach}";
      "dirlist_unread.bold" = true;
      "border.fg" = "#${surface1}";
      "tab.bg" = "#${mantle}";
      "tab.selected.bg" = "#${surface0}";
      "completion_pill.bg" = "#${surface0}";
      "selector_focused.reverse" = "toggle";
      "part_mimetype.fg" = "#${overlay1}";
    };
  };
}
