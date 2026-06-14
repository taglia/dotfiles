{
  config,
  lib,
  ...
}:

let
  managedPiAgentFiles = {
    ".pi/agent/AGENTS.md" = ../../files/pi/agent/AGENTS.md;
    ".pi/agent/settings.json" = ../../files/pi/agent/settings.json;
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

  home.file = lib.mapAttrs (_name: source: {
    inherit source;
    force = true;
  }) managedPiAgentFiles;
}
