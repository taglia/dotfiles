{
  config,
  lib,
  pkgs,
  ...
}:

let
  minimalWebSource = ../../files/pi/agent/extensions/minimal-web;

  managedPiAgentFiles = {
    ".pi/agent/AGENTS.md" = ../../files/pi/agent/AGENTS.md;
    ".pi/agent/settings.json" = ../../files/pi/agent/settings.json;
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

  prepareManagedPiAgentLinks = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: source:
      let
        target = "${config.home.homeDirectory}/${name}";
      in
      ''
        if [[ -f "${target}" && ! -L "${target}" ]] && ${pkgs.diffutils}/bin/cmp -s ${source} "${target}"; then
          ${pkgs.coreutils}/bin/rm "${target}"
        fi
      ''
    ) managedPiAgentFiles
  );
in
{
  home.activation.prepareManagedPiAgentLinks =
    lib.hm.dag.entryBetween [ "linkGeneration" ] [ "checkLinkTargets" ]
      prepareManagedPiAgentLinks;

  home.activation.installMinimalWebExtension = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -rf $VERBOSE_ARG ~/.pi/agent/extensions/minimal-web
    $DRY_RUN_CMD mkdir -p $VERBOSE_ARG ~/.pi/agent/extensions/minimal-web
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/cat ${minimalWebSource}/index.ts > ~/.pi/agent/extensions/minimal-web/index.ts
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/cat ${minimalWebSource}/package.json > ~/.pi/agent/extensions/minimal-web/package.json
    if [ ! -d ~/.pi/agent/extensions/minimal-web/node_modules ]; then
      $DRY_RUN_CMD ${pkgs.nodejs}/bin/npm install --prefix ~/.pi/agent/extensions/minimal-web --omit=dev
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
