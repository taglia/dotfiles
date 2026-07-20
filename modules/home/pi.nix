{
  lib,
  pkgs,
  ...
}:

let
  minimalWebSource = ../../files/pi/agent/extensions/minimal-web;
  settingsSource = ../../files/pi/agent/settings.json;

  catppuccin = import ../../lib/catppuccin.nix;
  inherit (catppuccin) palette;

  # pi theme generated from the shared palette: `vars` is the whole palette
  # with '#' prefixes, and `colors` maps pi's theme slots to var names. The
  # two toolSuccessBg/toolErrorBg backgrounds are custom dark blends with no
  # palette equivalent, so they stay literal.
  piTheme = {
    "$schema" =
      "https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json";
    name = "catppuccin-mocha";
    vars = lib.mapAttrs (_: hex: "#${hex}") palette;
    colors = {
      accent = "mauve";
      border = "surface1";
      borderAccent = "mauve";
      borderMuted = "surface0";
      success = "green";
      error = "red";
      warning = "peach";
      muted = "overlay1";
      dim = "overlay0";
      text = "text";
      thinkingText = "overlay2";

      selectedBg = "surface0";
      userMessageBg = "surface0";
      userMessageText = "text";
      customMessageBg = "surface0";
      customMessageText = "text";
      customMessageLabel = "mauve";
      toolPendingBg = "mantle";
      toolSuccessBg = "#1e2e1e";
      toolErrorBg = "#2e1e1e";
      toolTitle = "blue";
      toolOutput = "subtext1";

      mdHeading = "peach";
      mdLink = "sky";
      mdLinkUrl = "overlay1";
      mdCode = "pink";
      mdCodeBlock = "text";
      mdCodeBlockBorder = "surface1";
      mdQuote = "subtext0";
      mdQuoteBorder = "surface1";
      mdHr = "surface1";
      mdListBullet = "sky";

      toolDiffAdded = "green";
      toolDiffRemoved = "red";
      toolDiffContext = "overlay1";

      syntaxComment = "overlay1";
      syntaxKeyword = "mauve";
      syntaxFunction = "blue";
      syntaxVariable = "peach";
      syntaxString = "green";
      syntaxNumber = "peach";
      syntaxType = "yellow";
      syntaxOperator = "sky";
      syntaxPunctuation = "overlay2";

      thinkingOff = "overlay0";
      thinkingMinimal = "surface2";
      thinkingLow = "sky";
      thinkingMedium = "blue";
      thinkingHigh = "lavender";
      thinkingXhigh = "mauve";

      bashMode = "peach";
    };
    export = {
      pageBg = "#${palette.base}";
      cardBg = "#${palette.mantle}";
      infoBg = "#${palette.surface0}";
    };
  };

  # Pretty-printed via jq so the installed file stays readable.
  piThemeJson =
    pkgs.runCommand "catppuccin-mocha.json"
      {
        nativeBuildInputs = [ pkgs.jq ];
        json = builtins.toJSON piTheme;
      }
      ''
        echo "$json" | jq . > $out
      '';

  # settings.json is deliberately absent here: pi rewrites it at runtime
  # (lastChangelogVersion, /model, /theme), which would replace a store
  # symlink with a regular file and abort the next activation. It is
  # installed as a writable copy below instead.
  managedPiAgentFiles = {
    ".pi/agent/AGENTS.md" = ../../files/pi/agent/AGENTS.md;
    ".pi/agent/models.json" = ../../files/pi/agent/models.json;
    ".pi/agent/ascii-art/taglia-pi.txt" = ../../files/pi/agent/ascii-art/taglia-pi.txt;
    ".pi/agent/extensions/ascii-header.ts" = ../../files/pi/agent/extensions/ascii-header.ts;
    ".pi/agent/extensions/prettier-footer.ts" = ../../files/pi/agent/extensions/prettier-footer.ts;
    ".pi/agent/extensions/session-cost-breakdown.ts" =
      ../../files/pi/agent/extensions/session-cost-breakdown.ts;
    ".pi/agent/extensions/confirm-interrupt.ts" = ../../files/pi/agent/extensions/confirm-interrupt.ts;
    ".pi/agent/extensions/elapsed-time.ts" = ../../files/pi/agent/extensions/elapsed-time.ts;
  };
in
{
  # Writable copy of settings.json (see comment on managedPiAgentFiles). The
  # repo copy is the source of truth: runtime edits worth keeping should be
  # folded back into files/pi/agent/settings.json, otherwise the next switch
  # resets them.
  home.activation.installPiSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    pi_settings="$HOME/.pi/agent/settings.json"
    if [ -L "$pi_settings" ] \
      || ! ${pkgs.diffutils}/bin/cmp -s ${settingsSource} "$pi_settings"; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f $VERBOSE_ARG "$pi_settings"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 644 $VERBOSE_ARG \
        ${settingsSource} "$pi_settings"
    fi
  '';

  home.activation.installMinimalWebExtension = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    minimalWebTarget="$HOME/.pi/agent/extensions/minimal-web"

    # Decide whether dependencies need (re)installing before the lockfile
    # below is refreshed: only when node_modules is missing or the lockfile
    # changed, so activation works offline in the common case.
    minimalWebNeedsInstall=0
    if [ ! -d "$minimalWebTarget/node_modules" ] \
      || ! ${pkgs.diffutils}/bin/cmp -s ${minimalWebSource}/package-lock.json "$minimalWebTarget/package-lock.json"; then
      minimalWebNeedsInstall=1
    fi

    $DRY_RUN_CMD mkdir -p $VERBOSE_ARG "$minimalWebTarget"
    for f in index.ts package.json package-lock.json; do
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 644 $VERBOSE_ARG \
        ${minimalWebSource}/"$f" "$minimalWebTarget/$f"
    done

    if [ "$minimalWebNeedsInstall" = 1 ]; then
      # npm ci needs the network; a failure (e.g. an offline switch) must not
      # abort activation — the extension can install its dependencies later.
      if ! $DRY_RUN_CMD ${pkgs.nodejs}/bin/npm ci --prefix "$minimalWebTarget" --omit=dev; then
        echo "warning: npm ci failed for the minimal-web pi extension; run 'npm ci --omit=dev' in $minimalWebTarget later" >&2
      fi
    fi
  '';

  # pi-coding-agent ships its own bundled Node runtime, but at runtime it
  # shells out to a bare `npm` (see the `pi-vim` install into
  # ~/.pi/agent/npm) and relies on `npm` being on PATH. Provide nodejs here so
  # `npm`/`node` resolve wherever this profile (and thus pi-coding-agent) is
  # active. On hosts that manage Node via mise, mise's shims stay ahead of the
  # Nix profile in PATH, so this only fills the gap on hosts without a
  # mise-installed Node (e.g. a fresh VM).
  home.packages = [ pkgs.nodejs ];

  # All entries use `force = true`, so Home Manager's checkLinkTargets skips
  # the collision check and linkGeneration replaces any pre-existing file.
  home.file =
    lib.mapAttrs (_name: source: {
      inherit source;
      force = true;
    }) managedPiAgentFiles
    // {
      ".pi/agent/themes/catppuccin-mocha.json" = {
        source = piThemeJson;
        force = true;
      };
    };
}
