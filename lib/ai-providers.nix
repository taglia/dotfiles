# Single source of truth for the AI provider endpoints and model catalogs
# shared by the agent tools in this repo. Each consumer maps this data into
# its own config schema and chooses which model ids it exposes, so adding a
# model or correcting a context window is a one-file change here instead of a
# hand-synchronized edit across multiple formats.
#
# Consumers:
#   - modules/home/pi.nix        (models.json providers + model metadata)
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
    # publishes one. Rates: https://ollama.com/pricing (checked 2026-09-14).
    # cacheWrite = 0 means no separately published cache-write charge.
    models = {
      "glm-5.2" = {
        name = "GLM-5.2 (Ollama Cloud)";
        context = 1000000;
        cost = {
          input = 1.4;
          output = 4.4;
          cacheRead = 0.26;
          cacheWrite = 0;
        };
      };
      "glm-5.3" = {
        name = "GLM-5.3 (Ollama Cloud)";
        context = 1000000;
        cost = {
          input = 1.4;
          output = 4.4;
          cacheRead = 0.26;
          cacheWrite = 0;
        };
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
        cost = {
          input = 0.95;
          output = 4;
          cacheRead = 0.19;
          cacheWrite = 0;
        };
      };
      "deepseek-v4-pro" = {
        name = "DeepSeek V4 Pro (Ollama Cloud)";
        context = 262144;
        # Base rates only: weekday 12:00-18:00 UTC peak rates are double.
        # Consumers expose static estimates, not time-dependent billing.
        cost = {
          input = 0.66;
          output = 1.98;
          cacheRead = 0.022;
          cacheWrite = 0;
        };
      };
      "minimax-m3" = {
        name = "MiniMax M3 (Ollama Cloud)";
        context = 524288;
        cost = {
          input = 0.6;
          output = 2.4;
          cacheRead = 0.12;
          cacheWrite = 0;
        };
      };
    };
  };

  # Listed rates: https://opencode.ai/docs/zen/ (checked 2026-09-14).
  # These three legacy models are marked deprecated by Zen; retaining their
  # metadata does not enable them in any consumer. No separate cache-write fee.
  opencodeZen = {
    name = "OpenCode Zen";
    baseUrl = "https://opencode.ai/zen/v1";
    models = {
      "glm-5" = {
        name = "GLM-5 (OpenCode Zen)";
        context = 204800;
        cost = {
          input = 1;
          output = 3.2;
          cacheRead = 0.2;
          cacheWrite = 0;
        };
      };
      "kimi-k2.5" = {
        name = "Kimi K2.5 (OpenCode Zen)";
        context = 262144;
        cost = {
          input = 0.6;
          output = 3;
          cacheRead = 0.1;
          cacheWrite = 0;
        };
      };
      "minimax-m2.5" = {
        name = "MiniMax M2.5 (OpenCode Zen)";
        context = 204800;
        cost = {
          input = 0.3;
          output = 1.2;
          cacheRead = 0.06;
          cacheWrite = 0;
        };
      };
    };
  };
}
