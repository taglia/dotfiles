{ config, lib, ... }:

let
  kagiSecretFile = ../secrets/pi-kagi-api-key.age;
  ollamaSecretFile = ../secrets/pi-ollama-api-key.age;
  agenixDir = "${config.home.homeDirectory}/.local/share/agenix";
  agenixMountPoint = "${config.home.homeDirectory}/.local/share/agenix.d";

  secretEnv =
    (lib.optionalAttrs (config.age.secrets ? pi_kagi_api_key) {
      KAGI_API_KEY_FILE = config.age.secrets.pi_kagi_api_key.path;
    })
    // (lib.optionalAttrs (config.age.secrets ? pi_ollama_api_key) {
      OLLAMA_API_KEY_FILE = config.age.secrets.pi_ollama_api_key.path;
    });
in
{
  age.identityPaths = [
    "${config.home.homeDirectory}/.ssh/id_rsa"
    "${config.home.homeDirectory}/.ssh/id_ed25519"
  ];
  age.secretsDir = agenixDir;
  age.secretsMountPoint = agenixMountPoint;

  age.secrets =
    (lib.optionalAttrs (builtins.pathExists kagiSecretFile) {
      pi_kagi_api_key.file = kagiSecretFile;
    })
    // (lib.optionalAttrs (builtins.pathExists ollamaSecretFile) {
      pi_ollama_api_key.file = ollamaSecretFile;
    });

  home.sessionVariables = secretEnv;

  programs.atuin.settings = {
    auto_sync = true;
    sync_frequency = "5m";
  };
}
