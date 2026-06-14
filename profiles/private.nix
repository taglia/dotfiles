{ config, lib, ... }:

let
  kagiSecretFile = ../secrets/pi-kagi-api-key.age;
  agenixDir = "${config.home.homeDirectory}/.local/share/agenix";
  agenixMountPoint = "${config.home.homeDirectory}/.local/share/agenix.d";
in
{
  age.identityPaths = [ "${config.home.homeDirectory}/.ssh/id_rsa" ];
  age.secretsDir = agenixDir;
  age.secretsMountPoint = agenixMountPoint;

  age.secrets = lib.optionalAttrs (builtins.pathExists kagiSecretFile) {
    pi_kagi_api_key.file = kagiSecretFile;
  };

  programs.bash.sessionVariables = lib.optionalAttrs (config.age.secrets ? pi_kagi_api_key) {
    KAGI_API_KEY_FILE = config.age.secrets.pi_kagi_api_key.path;
  };

  programs.zsh.sessionVariables = lib.optionalAttrs (config.age.secrets ? pi_kagi_api_key) {
    KAGI_API_KEY_FILE = config.age.secrets.pi_kagi_api_key.path;
  };

  programs.fish.shellInit = lib.mkIf (config.age.secrets ? pi_kagi_api_key) ''
    set -gx KAGI_API_KEY_FILE ${lib.escapeShellArg config.age.secrets.pi_kagi_api_key.path}
  '';

  programs.atuin.settings = {
    auto_sync = true;
    sync_frequency = "5m";
  };
}
