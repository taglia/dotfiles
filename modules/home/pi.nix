{
  config,
  lib,
  pkgs,
  ...
}:

let
  minimalWebSource = ../../files/pi/agent/extensions/minimal-web;

  minimalWebExtension = pkgs.stdenv.mkDerivation {
    name = "pi-minimal-web";
    src = minimalWebSource;
    nativeBuildInputs = [ pkgs.nodejs ];
    buildPhase = ''
      npm install --omit=dev
    '';
    installPhase = ''
      mkdir -p $out
      cp index.ts $out/
      cp package.json $out/
      cp -r node_modules $out/
    '';
  };

  managedPiAgentFiles = {
    ".pi/agent/AGENTS.md" = ../../files/pi/agent/AGENTS.md;
    ".pi/agent/settings.json" = ../../files/pi/agent/settings.json;
    ".pi/agent/models.json" = ../../files/pi/agent/models.json;
    ".pi/agent/ascii-art/taglia-pi.txt" = ../../files/pi/agent/ascii-art/taglia-pi.txt;
    ".pi/agent/extensions/ascii-header.ts" = ../../files/pi/agent/extensions/ascii-header.ts;
    ".pi/agent/extensions/prettier-footer.ts" = ../../files/pi/agent/extensions/prettier-footer.ts;
    ".pi/agent/extensions/session-cost-breakdown.ts" =
      ../../files/pi/agent/extensions/session-cost-breakdown.ts;
    ".pi/agent/extensions/minimal-web" = minimalWebExtension;
  };

  prepareManagedPiAgentLinks = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: source:
      let
        target = "${config.home.homeDirectory}/${name}";
      in
      ''
        if [[ -f "${target}" && ! -L "${target}" ]] && /usr/bin/cmp -s ${source} "${target}"; then
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
