{ config, lib, ... }:

let
  kagiSecretFile = ../secrets/pi-kagi-api-key.age;
  ollamaSecretFile = ../secrets/pi-ollama-api-key.age;
  agenixDir = "${config.home.homeDirectory}/.local/share/agenix";

  secretEnv =
    (lib.optionalAttrs (builtins.pathExists kagiSecretFile) {
      KAGI_API_KEY_FILE = "${agenixDir}/pi_kagi_api_key";
    })
    // (lib.optionalAttrs (builtins.pathExists ollamaSecretFile) {
      OLLAMA_API_KEY_FILE = "${agenixDir}/pi_ollama_api_key";
    });
in
{
  age.identityPaths = [
    "${config.home.homeDirectory}/.ssh/id_rsa"
    "${config.home.homeDirectory}/.ssh/id_ed25519"
  ];
  age.secretsDir = agenixDir;
  age.secretsMountPoint = agenixDir;

  age.secrets =
    (lib.optionalAttrs (builtins.pathExists kagiSecretFile) {
      pi_kagi_api_key = {
        file = kagiSecretFile;
        path = "${agenixDir}/pi_kagi_api_key";
      };
    })
    // (lib.optionalAttrs (builtins.pathExists ollamaSecretFile) {
      pi_ollama_api_key = {
        file = ollamaSecretFile;
        path = "${agenixDir}/pi_ollama_api_key";
      };
    });

  home.sessionVariables = secretEnv;

  programs.atuin.settings = {
    auto_sync = true;
    sync_frequency = "5m";
  };
}
