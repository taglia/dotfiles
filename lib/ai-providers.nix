# Single source of truth for the AI provider endpoints and model catalogs
# shared by the agent tools in this repo. Each consumer maps this data into
# its own config schema and chooses which model ids it exposes, so adding a
# model or correcting a context window is a one-file change here instead of a
# hand-synchronized edit across three formats.
#
# Consumers:
#   - modules/home/goose.nix     (custom-provider JSON + wrapper defaults)
#   - modules/home/crush.nix     (crush.json providers + default model pair)
#   - modules/home/opencode.nix  (opencode.json provider + default model pair)
#
# Endpoints are pinned here on purpose (see the consumers' comments): a
# compromised upstream catalog must never be able to redirect requests (and
# the Bearer keys) to a host of its choosing.
{
  # Default large/small model pair used by every tool.
  defaultModels = {
    large = "glm-5.2";
    small = "minimax-m3";
  };

  ollamaCloud = {
    name = "Ollama Cloud";
    baseUrl = "https://ollama.com/v1";
    # `context` is the model's context window in tokens; `attachments` marks
    # image-capable models; `cost` is USD per 1M tokens where Ollama Cloud
    # publishes one.
    models = {
      "glm-5.2" = {
        name = "GLM-5.2 (Ollama Cloud)";
        context = 1000000;
      };
      "kimi-k3" = {
        name = "Kimi K3 (Ollama Cloud)";
        context = 1000000;
        attachments = true;
        cost = {
          input = 3;
          output = 15;
          cacheRead = 0.3;
          cacheWrite = 0;
        };
      };
      "kimi-k2.7-code" = {
        name = "Kimi K2.7 Code (Ollama Cloud)";
        context = 262144;
      };
      "deepseek-v4-pro" = {
        name = "DeepSeek V4 Pro (Ollama Cloud)";
        context = 262144;
      };
      "minimax-m3" = {
        name = "MiniMax M3 (Ollama Cloud)";
        context = 524288;
      };
    };
  };

  opencodeZen = {
    name = "OpenCode Zen";
    baseUrl = "https://opencode.ai/zen/v1";
    models = {
      "glm-5" = {
        name = "GLM-5 (OpenCode Zen)";
        context = 204800;
      };
      "kimi-k2.5" = {
        name = "Kimi K2.5 (OpenCode Zen)";
        context = 262144;
      };
      "minimax-m2.5" = {
        name = "MiniMax M2.5 (OpenCode Zen)";
        context = 204800;
      };
    };
  };
}
