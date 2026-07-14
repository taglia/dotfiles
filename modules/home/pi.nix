{
  config,
  lib,
  pkgs,
  ...
}:

let
  minimalWebSource = ../../files/pi/agent/extensions/minimal-web;
  settingsSource = ../../files/pi/agent/settings.json;
  prepareLinks = import ../../lib/prepare-links.nix { inherit lib pkgs; };

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
    ".pi/agent/themes/catppuccin-mocha.json" = ../../files/pi/agent/themes/catppuccin-mocha.json;
  };
in
{
  home.activation.prepareManagedPiAgentLinks =
    lib.hm.dag.entryBetween [ "linkGeneration" ] [ "checkLinkTargets" ]
      (
        prepareLinks (
          lib.mapAttrs' (
            name: source: lib.nameValuePair "${config.home.homeDirectory}/${name}" source
          ) managedPiAgentFiles
        )
      );

  # Writable copy of settings.json (see comment on managedPiAgentFiles). The
  # repo copy is the source of truth: runtime edits worth keeping should be
  # folded back into files/pi/agent/settings.json, otherwise the next switch
  # resets them.
  home.activation.installPiSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -L ~/.pi/agent/settings.json ] \
      || ! ${pkgs.diffutils}/bin/cmp -s ${settingsSource} ~/.pi/agent/settings.json; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f $VERBOSE_ARG ~/.pi/agent/settings.json
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 644 $VERBOSE_ARG \
        ${settingsSource} ~/.pi/agent/settings.json
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
      $DRY_RUN_CMD ${pkgs.nodejs}/bin/npm ci --prefix "$minimalWebTarget" --omit=dev
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

  home.file = lib.mapAttrs (_name: source: {
    inherit source;
    force = true;
  }) managedPiAgentFiles;
}
