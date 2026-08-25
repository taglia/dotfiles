# Single source of truth for Homebrew tap-trust entries. Consumed by:
#   - modules/darwin/homebrew.nix       (nix-homebrew.trust, applied at
#     activation via `sudo -u <admin> -H brew trust`, which writes
#     ~/.homebrew/trust.json — the path brew uses when XDG_CONFIG_HOME is
#     unset, as in the activation context)
#   - modules/home/homebrew-trust.nix   (declarative
#     $XDG_CONFIG_HOME/homebrew/trust.json — the path brew uses in
#     interactive shells, where shells.nix exports XDG_CONFIG_HOME)
# Both must be covered: brew consults exactly one of the two files depending
# on whether XDG_CONFIG_HOME is set, so trusting only via nix-homebrew leaves
# interactive `brew cleanup`/`brew bundle` refusing the cask.
{
  casks = [ "kitknox/rootshell/rootshell" ];
}
