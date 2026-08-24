{ lib, pkgs, ... }:

let
  json = pkgs.formats.json { };

  aiProviders = import ../../lib/ai-providers.nix;
  inherit (aiProviders) defaultModels;

  # Model ids exposed to OpenCode (also its whitelist); the facts behind each
  # id live in lib/ai-providers.nix, shared with goose.nix and crush.nix.
  ollamaCloudIds = [
    "minimax-m3"
    "kimi-k2.7-code"
    "deepseek-v4-pro"
    "glm-5.2"
    "kimi-k3"
  ];

  mkOllamaModel =
    id:
    let
      m = aiProviders.ollamaCloud.models.${id};
    in
    {
      inherit (m) name;
      reasoning = true;
      limit = {
        inherit (m) context;
        output = 65536;
      };
    }
    // lib.optionalAttrs (m ? attachments) {
      attachment = m.attachments;
      modalities.input = [
        "text"
        "image"
      ];
      modalities.output = [ "text" ];
    }
    // lib.optionalAttrs (m ? cost) {
      cost = {
        input = m.cost.input;
        output = m.cost.output;
        cache_read = m.cost.cacheRead;
        cache_write = m.cost.cacheWrite;
      };
    };

  opencodeConfig = json.generate "opencode.json" {
    "$schema" = "https://opencode.ai/config.json";

    model = "ollama-cloud/${defaultModels.large}";
    small_model = "ollama-cloud/${defaultModels.small}";
    # ollama-cloud is credentialled via the agenix file token below. The
    # others (openai, opencode, anthropic, openrouter) authenticate through
    # /connect, which stores tokens in ~/.local/share/opencode/auth.json
    # outside the immutable Nix-managed config directory.
    enabled_providers = [
      "ollama-cloud"
      "openai"
      "opencode"
      "anthropic"
      "openrouter"
    ];

    provider.ollama-cloud = {
      inherit (aiProviders.ollamaCloud) name;
      whitelist = ollamaCloudIds;
      # This adapter ships inside OpenCode. Naming it explicitly prevents a
      # catalog update from selecting a package that OpenCode downloads later.
      npm = "@ai-sdk/openai-compatible";
      options = {
        apiKey = "{file:{env:OLLAMA_API_KEY_FILE}}";
        baseURL = aiProviders.ollamaCloud.baseUrl;
        timeout = 300000;
        chunkTimeout = 30000;
      };
      models = lib.genAttrs ollamaCloudIds mkOllamaModel;
    };

    share = "disabled";
    autoupdate = false;
    snapshot = true;
    subagent_depth = 1;
    formatter = false;
    lsp = false;
    plugin = [ ];
    mcp = { };
    skills = {
      paths = [ ];
      urls = [ ];
    };
    server = {
      hostname = "127.0.0.1";
      mdns = false;
    };
    experimental.openTelemetry = false;

    # OpenCode otherwise permits every tool without confirmation. Keep normal
    # repository inspection frictionless, but require approval before commands,
    # edits, subprocess agents, or network access and make secret paths
    # inaccessible to the model.
    permission = {
      read = {
        "*" = "allow";
        "*.env" = "ask";
        "*.env.*" = "ask";
        "~/.local/share/agenix/**" = "deny";
        "~/.ssh/**" = "deny";
      };
      edit = "ask";
      glob = "allow";
      grep = "allow";
      list = "allow";
      bash = {
        "*" = "ask";
        "bunx *" = "deny";
        "npx *" = "deny";
      };
      task = "ask";
      external_directory = {
        "*" = "ask";
        "~/.local/share/agenix/**" = "deny";
        "~/.ssh/**" = "deny";
      };
      todowrite = "allow";
      question = "allow";
      webfetch = "ask";
      websearch = "ask";
      lsp = "deny";
      doom_loop = "deny";
      skill = "deny";
    };
  };

  tuiConfig = json.generate "tui.json" {
    "$schema" = "https://opencode.ai/tui.json";
    theme = "catppuccin";
  };

  # OpenCode otherwise bootstraps @opencode-ai/plugin into every writable
  # config directory, even when no plugin is configured. Symlinking the whole
  # directory to the Nix store makes that implicit npm installation impossible.
  configDir = pkgs.linkFarm "opencode-config" [
    {
      name = "opencode.json";
      path = opencodeConfig;
    }
    {
      name = "tui.json";
      path = tuiConfig;
    }
    {
      name = "AGENTS.md";
      path = ../../files/opencode/AGENTS.md;
    }
  ];
in
{
  xdg.configFile.opencode = {
    source = configDir;
    force = true;
  };

  home.sessionVariables = {
    # Do not execute code or load instructions supplied by a checked-out repo.
    OPENCODE_DISABLE_PROJECT_CONFIG = "1";
    OPENCODE_PURE = "1";
    OPENCODE_DISABLE_DEFAULT_PLUGINS = "1";
    OPENCODE_DISABLE_EXTERNAL_SKILLS = "1";
    OPENCODE_DISABLE_CLAUDE_CODE = "1";

    # Keep the Nix-pinned binary and bundled provider metadata authoritative.
    OPENCODE_DISABLE_AUTOUPDATE = "1";
    OPENCODE_DISABLE_MODELS_FETCH = "1";
    OPENCODE_DISABLE_LSP_DOWNLOAD = "1";

    # OpenCode's built-in search client talks directly to Exa's hosted MCP
    # endpoint; no local MCP server, plugin, or runtime package is involved.
    OPENCODE_ENABLE_EXA = "1";
    OPENCODE_WEBSEARCH_PROVIDER = "exa";
  };
}
