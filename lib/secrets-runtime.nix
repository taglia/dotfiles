# Runtime location of the stable consumer symlinks that profiles/private.nix
# deploys for agenix secrets (its `envFilePath`). Modules that read secrets at
# *runtime* (wrapper scripts, generated app configs) deliberately build the
# path from the invoking shell's $HOME rather than config.age.secrets.<name>.path:
# it keeps hosts that do not wire secrets evaluating (no eval-time dependency
# on age.secrets) and resolves correctly on both /Users/* and /home/* layouts.
# profiles/private.nix builds the same path at eval time from
# config.home.homeDirectory; the shared `dir` constant here is what keeps the
# two from drifting.
rec {
  # Relative to the home directory.
  dir = ".local/share/agenix";

  # Path of secret <name> for interpolation into shell scripts ($HOME is
  # expanded by the shell at runtime, unquoted here — embed inside a quoted
  # context at the call site).
  shellFile = name: "$HOME/${dir}/${name}";
}
