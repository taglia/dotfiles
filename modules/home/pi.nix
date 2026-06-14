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
  };

  prepareManagedPiAgentLinks = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: source:
      let
        target = "${config.home.homeDirectory}/${name}";
      in
      ''
        if [[ -e "${target}" && ! -L "${target}" ]] && /usr/bin/cmp -s ${source} "${target}"; then
          /bin/rm "${target}"
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
    $DRY_RUN_CMD mkdir -p $VERBOSE_ARG ~/.pi/agent/extensions/minimal-web
    $DRY_RUN_CMD cp $VERBOSE_ARG ${minimalWebSource}/index.ts ~/.pi/agent/extensions/minimal-web/index.ts
    $DRY_RUN_CMD cp $VERBOSE_ARG ${minimalWebSource}/package.json ~/.pi/agent/extensions/minimal-web/package.json
    if [ ! -d ~/.pi/agent/extensions/minimal-web/node_modules ]; then
      $DRY_RUN_CMD ${pkgs.nodejs}/bin/npm install --prefix ~/.pi/agent/extensions/minimal-web --omit=dev
    fi
  '';

  home.file = lib.mapAttrs (_name: source: {
    inherit source;
    force = true;
  }) managedPiAgentFiles;
}
