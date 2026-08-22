# Global configuration for Crush (charmbracelet/crush). Only the global
# ~/.config/crush/crush.json is managed here; Crush keeps model selection and
# session state in its data directory, so the Nix store symlink stays
# read-only. Project-level crush.json files still merge on top of this one.
#
# API keys never live in this file or the store: providers expand them at
# startup with shell commands that read the agenix-deployed symlinks under
# ~/.local/share/agenix/ directly, so no environment variables need to reach
# Crush; the nono profile only needs a narrow read_file grant per key file.
{ pkgs, ... }:

let
  json = pkgs.formats.json { };

  ollamaModel =
    id: name: contextWindow: extra:
    {
      inherit id name;
      context_window = contextWindow;
      default_max_tokens = 65536;
      can_reason = true;
    }
    // extra;

  crushConfig = json.generate "crush.json" {
    "$schema" = "https://charm.land/crush.json";

    options = {
      tui.transparent = true;

      # Hardening: no telemetry, and do not let Crush rewrite its provider
      # catalog behind the pinned configuration below.
      disable_metrics = true;
      disable_provider_auto_update = true;
    };

    permissions.allowed_tools = [
      # Read-only tools stay frictionless; anything mutating still prompts.
      "view"
      "ls"
      "grep"
      "glob"
    ];

    models = {
      large = {
        model = "glm-5.2";
        provider = "ollama-cloud";
      };
      small = {
        model = "minimax-m3";
        provider = "ollama-cloud";
      };
    };

    providers.ollama-cloud = {
      name = "Ollama Cloud";
      type = "openai-compat";
      base_url = "https://ollama.com/v1";
      api_key = "$(cat \"$HOME\"/.local/share/agenix/pi_ollama_api_key)";
      # Only the explicitly listed models below; no /v1/models discovery
      # against the cloud endpoint.
      discover_models = false;
      models = [
        (ollamaModel "glm-5.2" "GLM-5.2 (Ollama Cloud)" 1000000 { })
        (ollamaModel "kimi-k3" "Kimi K3 (Ollama Cloud)" 1000000 {
          supports_attachments = true;
          cost_per_1m_in = 3;
          cost_per_1m_out = 15;
          cost_per_1m_in_cached = 0.3;
          cost_per_1m_out_cached = 0;
        })
        (ollamaModel "deepseek-v4-pro" "DeepSeek V4 Pro (Ollama Cloud)" 262144 { })
        (ollamaModel "minimax-m3" "MiniMax M3 (Ollama Cloud)" 524288 { })
      ];
    };

    # OpenCode Zen: the id must be exactly "opencode-zen" so Crush recognizes
    # it as a known provider. The model catalog (all currently supported Zen
    # models, their costs, context windows, and per-model API protocol) comes
    # from the catwalk snapshot embedded in each Crush release and is
    # maintained upstream; here we only supply credentials.
    #
    # base_url is pinned explicitly even though the catalog provides one: the
    # catalog's api_endpoint would otherwise be trusted wholesale, and a
    # compromised upstream could redirect requests (and the Bearer key) to a
    # host of its choosing. With this override the endpoint only ever changes
    # through a reviewed commit here.
    providers.opencode-zen = {
      base_url = "https://opencode.ai/zen/v1";
      api_key = "$(cat \"$HOME\"/.local/share/agenix/opencode_zen_api_key)";
    };
  };
in
{
  xdg.configFile."crush/crush.json".source = crushConfig;
}
