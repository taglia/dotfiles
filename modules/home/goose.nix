# Global configuration for Goose CLI (aaif-goose/goose). Provider credentials
# stay in agenix files and are read only when the wrapper starts Goose; neither
# the keys nor their values enter the Nix store.
{ pkgs, pkgs-unstable, ... }:

let
  yaml = pkgs.formats.yaml { };
  json = pkgs.formats.json { };

  platformExtension = enabled: name: display_name: description: {
    inherit
      enabled
      name
      display_name
      description
      ;
    type = "platform";
    bundled = true;
    available_tools = [ ];
  };

  # Claude's safe mode disables inherited MCPs, plugins, hooks, LSP, and
  # project instructions while preserving normal authentication.
  claudeSafe = pkgs.writeShellScriptBin "claude-goose" ''
    unset \
      OLLAMA_API_KEY OPENROUTER_API_KEY OPENCODE_API_KEY \
      ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN
    exec ${pkgs-unstable.claude-code}/bin/claude --safe-mode "$@"
  '';

  # Goose's CLI provider can use the current, separately packaged Codex CLI.
  # Give it only the subscription token in an ephemeral home and put the
  # security overrides before Goose's arguments so they apply to subcommands.
  codexCliSafe = pkgs.writeShellScriptBin "codex-goose" ''
    set -euo pipefail
    unset \
      OLLAMA_API_KEY OPENROUTER_API_KEY OPENCODE_API_KEY \
      OPENAI_API_KEY CODEX_API_KEY CODEX_CONFIG MODEL_PROVIDER

    isolated_home="$(mktemp -d)"
    cleanup() { rm -rf -- "$isolated_home"; }
    trap cleanup EXIT HUP INT TERM

    if [[ -f "$HOME/.codex/auth.json" ]]; then
      ln -s "$HOME/.codex/auth.json" "$isolated_home/auth.json"
    fi

    CODEX_HOME="$isolated_home" ${pkgs-unstable.codex}/bin/codex \
      -c 'mcp_servers={}' \
      -c 'project_doc_max_bytes=0' \
      -c 'features.skills=false' \
      "$@"
  '';

  # Expose the pinned ACP adapters to Goose only through constrained wrappers.
  # Codex gets an ephemeral home containing only its OAuth token; final CLI
  # overrides prevent project/user configuration from adding MCP servers,
  # project instructions, or skills. All children inherit these restrictions.
  codexAcpSafe = pkgs.writeShellScriptBin "codex-acp" ''
    set -euo pipefail
    # codex-acp 0.13 embeds Codex 0.128 rather than invoking the separately
    # packaged Codex CLI. GPT-5.6 Sol rejects that older embedded client.
    codex_model="''${GOOSE_CODEX_ACP_MODEL:-gpt-5.4}"
    unset \
      OLLAMA_API_KEY OPENROUTER_API_KEY OPENCODE_API_KEY \
      OPENAI_API_KEY CODEX_API_KEY CODEX_CONFIG MODEL_PROVIDER \
      GOOSE_CODEX_ACP_MODEL

    if [[ ! "$codex_model" =~ ^[a-zA-Z0-9._:-]+$ ]]; then
      echo "error: invalid Codex model identifier: $codex_model" >&2
      exit 2
    fi

    isolated_home="$(mktemp -d)"
    cleanup() { rm -rf -- "$isolated_home"; }
    trap cleanup EXIT HUP INT TERM

    if [[ -f "$HOME/.codex/auth.json" ]]; then
      ln -s "$HOME/.codex/auth.json" "$isolated_home/auth.json"
    fi

    CODEX_HOME="$isolated_home" ${pkgs-unstable.codex-acp}/bin/codex-acp \
      "$@" \
      -c "model=\"$codex_model\"" \
      -c 'mcp_servers={}' \
      -c 'project_doc_max_bytes=0' \
      -c 'features.skills=false'
  '';

  # The Nix adapter normally points at the raw Claude binary. Override that
  # default with the safe-mode wrapper so subscription auth remains available
  # while MCP, plugins, hooks, LSP, and project instructions stay disabled.
  claudeAcpSafe = pkgs.writeShellScriptBin "claude-agent-acp" ''
    set -euo pipefail
    claude_model="''${GOOSE_CLAUDE_ACP_MODEL:-claude-sonnet-5}"
    unset \
      OLLAMA_API_KEY OPENROUTER_API_KEY OPENCODE_API_KEY \
      ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN \
      GOOSE_CLAUDE_ACP_MODEL

    if [[ ! "$claude_model" =~ ^[-a-zA-Z0-9._:]+$ ]]; then
      echo "error: invalid Claude model identifier: $claude_model" >&2
      exit 2
    fi

    export ANTHROPIC_MODEL="$claude_model"
    export CLAUDE_CODE_EXECUTABLE="${claudeSafe}/bin/claude-goose"
    exec ${pkgs-unstable.claude-agent-acp}/bin/claude-agent-acp "$@"
  '';

  gooseConfig = yaml.generate "goose-config.yaml" {
    # Goose 1.28 (currently in nixpkgs unstable) uses these flat keys. They
    # remain supported by newer Goose versions as migration-compatible input.
    GOOSE_PROVIDER = "ollama-cloud";
    GOOSE_MODEL = "glm-5.2";
    GOOSE_FAST_MODEL = "minimax-m3";
    # Resolve subscription-backed CLI providers only to reviewed Nix-store
    # wrappers, never to a project-local or package-manager-installed binary.
    CODEX_COMMAND = "${codexCliSafe}/bin/codex-goose";
    CLAUDE_CODE_COMMAND = "${claudeSafe}/bin/claude-goose";
    # Let Goose classify tool calls and automatically approve those it judges
    # safe, while retaining prompts for calls that require human approval.
    GOOSE_MODE = "smart_approve";

    # Defense in depth: the wrapper also forces the environment opt-out, which
    # has higher precedence than this immutable config value.
    GOOSE_TELEMETRY_ENABLED = false;
    SECURITY_PROMPT_ENABLED = true;

    # Goose otherwise loads .goosehints and AGENTS.md automatically from the
    # git root through cwd, follows @file imports from those hints, and later
    # loads matching files from subdirectories touched by tool calls.
    CONTEXT_FILE_NAMES = [ ];

    # Declare the entire platform-extension set with the exact metadata bundled
    # in Goose 1.28, preventing its migration code from silently enabling new
    # capabilities. Keep only the local coding essentials enabled.
    extensions = {
      analyze =
        platformExtension true "analyze" "Analyze"
          "Analyze code structure with tree-sitter: directory overviews, file details, symbol call graphs";
      todo =
        platformExtension true "todo" "Todo"
          "Enable a todo list for goose so it can keep track of what it is doing";
      developer =
        platformExtension true "developer" "Developer"
          "Write and edit files, and execute shell commands";

      apps =
        platformExtension false "apps" "Apps"
          "Create and manage custom Goose apps through chat. Apps are HTML/CSS/JavaScript and run in sandboxed windows.";
      chatrecall =
        platformExtension false "chatrecall" "Chat Recall"
          "Search past conversations and load session summaries for contextual memory";
      extensionmanager =
        platformExtension false "Extension Manager" "Extension Manager"
          "Enable extension management tools for discovering, enabling, and disabling extensions";
      summon = platformExtension false "summon" "Summon" "Load knowledge and delegate tasks to subagents";
      summarize =
        platformExtension false "summarize" "Summarize"
          "Load files/directories and get an LLM summary in a single call";
      tom =
        platformExtension false "tom" "Top Of Mind"
          "Inject custom context into every turn via GOOSE_MOIM_MESSAGE_TEXT and GOOSE_MOIM_MESSAGE_FILE environment variables";
    };
  };

  model = name: context_limit: { inherit name context_limit; };

  # Goose's catalog can create this provider interactively, but managing the
  # JSON here pins the endpoint and exposes exactly the same Ollama Cloud model
  # set used by Crush.
  ollamaCloudProvider = json.generate "ollama-cloud.json" {
    name = "ollama-cloud";
    engine = "openai";
    display_name = "Ollama Cloud";
    description = "Ollama hosted models";
    api_key_env = "OLLAMA_API_KEY";
    base_url = "https://ollama.com/v1";
    models = [
      (model "glm-5.2" 1000000)
      (model "kimi-k3" 1000000)
      (model "deepseek-v4-pro" 262144)
      (model "minimax-m3" 524288)
    ];
    supports_streaming = true;
    requires_auth = true;
  };

  # As with Crush, pin Zen's endpoint rather than trusting a remotely supplied
  # URL. Goose accepts arbitrary model names at the CLI; these entries seed its
  # model picker with the relevant Zen catalog models in the bundled snapshot.
  opencodeProvider = json.generate "opencode.json" {
    name = "opencode";
    engine = "openai";
    display_name = "OpenCode Zen";
    description = "OpenCode Zen model gateway";
    api_key_env = "OPENCODE_API_KEY";
    base_url = "https://opencode.ai/zen/v1";
    models = [
      (model "glm-5" 204800)
      (model "kimi-k2.5" 262144)
      (model "minimax-m2.5" 204800)
    ];
    supports_streaming = true;
    requires_auth = true;
  };

  gooseWrapper = pkgs.writeShellScriptBin "goose" ''
    set -euo pipefail

    config_dir="$HOME/.config/goose"

    # Goose 1.28 has no single "disable MCP" switch. Reject every startup
    # input that can carry stdio, HTTP, or bundled MCP extensions. Recipes are
    # included because they can declare extensions themselves.
    for arg in "$@"; do
      case "$arg" in
        --with-extension|--with-extension=*|\
        --with-streamable-http-extension|--with-streamable-http-extension=*|\
        --with-builtin|--with-builtin=*|\
        --recipe|--recipe=*)
          echo "error: refusing to start Goose: MCP-capable option is disabled: $arg" >&2
          exit 1
          ;;
      esac
    done

    # Home Manager owns the trust roots. Refuse to run if a mutable file has
    # replaced one of its store-backed symlinks, or if another provider JSON
    # has been added (custom provider files control destinations and headers).
    for managed in \
      "$config_dir/config.yaml:${gooseConfig}" \
      "$config_dir/custom_providers/ollama-cloud.json:${ollamaCloudProvider}" \
      "$config_dir/custom_providers/opencode.json:${opencodeProvider}"
    do
      path="''${managed%%:*}"
      expected="''${managed#*:}"
      if [[ ! -L "$path" || ! "$path" -ef "$expected" ]]; then
        echo "error: refusing to start Goose: unmanaged or modified config at $path" >&2
        echo "hint: run your Home Manager switch to restore the managed configuration" >&2
        exit 1
      fi
    done

    shopt -s nullglob
    for provider in "$config_dir/custom_providers"/*.json; do
      case "$provider" in
        "$config_dir/custom_providers/ollama-cloud.json"|\
        "$config_dir/custom_providers/opencode.json") ;;
        *)
          echo "error: refusing to start Goose: unreviewed provider config at $provider" >&2
          exit 1
          ;;
      esac
    done
    shopt -u nullglob

    # Do not allow the caller (or a sourced project environment) to redirect
    # config discovery, substitute a generic provider, or inject model metadata.
    unset \
      GOOSE_PATH_ROOT \
      GOOSE_PROVIDER__TYPE \
      GOOSE_PROVIDER__HOST \
      GOOSE_PROVIDER__API_KEY \
      GOOSE_PREDEFINED_MODELS \
      GOOSE_MOIM_MESSAGE_TEXT \
      GOOSE_MOIM_MESSAGE_FILE \
      OPENAI_API_KEY \
      OPENAI_HOST \
      OPENAI_BASE_PATH

    # The dedicated launchers pass a private selector rather than relying on
    # caller-controlled provider environment variables. Interactive sessions
    # take their provider and model from this environment.
    provider="ollama-cloud"
    model="glm-5.2"
    if [[ "''${1-}" == "--hardened-provider" ]]; then
      case "''${2-}" in
        codex)
          provider="codex"
          model="''${3-}"
          ;;
        claude)
          provider="claude-code"
          model="''${3-}"
          ;;
        codex-acp)
          provider="codex-acp"
          model="''${3-}"
          export GOOSE_CODEX_ACP_MODEL="$model"
          ;;
        claude-acp)
          provider="claude-acp"
          model="''${3-}"
          export GOOSE_CLAUDE_ACP_MODEL="$model"
          ;;
        chatgpt)
          provider="chatgpt_codex"
          model="gpt-5.1-codex"
          ;;
        *)
          echo "error: unknown hardened Goose provider selector" >&2
          exit 2
          ;;
      esac
      shift 3
    fi

    # Environment values outrank config.yaml, so force the reviewed selection
    # and endpoint rather than inheriting potentially hostile shell values.
    export GOOSE_PROVIDER="$provider"
    export GOOSE_MODEL="$model"
    export GOOSE_FAST_MODEL="minimax-m3"
    export GOOSE_MODE="smart_approve"
    export GOOSE_TELEMETRY_OFF="1"
    export SECURITY_PROMPT_ENABLED="true"
    export CONTEXT_FILE_NAMES="[]"
    export OPENROUTER_HOST="https://openrouter.ai"

    export OLLAMA_API_KEY="$(<"$HOME/.local/share/agenix/pi_ollama_api_key")"
    export OPENROUTER_API_KEY="$(<"$HOME/.local/share/agenix/openrouter_api_key")"
    export OPENCODE_API_KEY="$(<"$HOME/.local/share/agenix/opencode_zen_api_key")"

    exec ${pkgs-unstable.goose-cli}/bin/goose "$@"
  '';

  # The primary launchers use the separately packaged proprietary CLIs so new
  # subscription models are not limited by the older runtime embedded in an
  # ACP adapter. Explicit ACP launchers remain available for compatibility
  # testing and can become primary once the adapters catch up.
  gooseCodex = pkgs.writeShellScriptBin "goose-codex" ''
    set -euo pipefail
    model="gpt-5.6-sol"
    if [[ "''${1-}" == "--model" ]]; then
      [[ -n "''${2-}" ]] || { echo "error: --model requires a value" >&2; exit 2; }
      model="$2"
      shift 2
    elif [[ "''${1-}" == --model=* ]]; then
      model="''${1#--model=}"
      shift
    fi
    exec ${gooseWrapper}/bin/goose --hardened-provider codex "$model" session "$@"
  '';
  gooseClaude = pkgs.writeShellScriptBin "goose-claude" ''
    set -euo pipefail
    model="claude-sonnet-5"
    if [[ "''${1-}" == "--model" ]]; then
      [[ -n "''${2-}" ]] || { echo "error: --model requires a value" >&2; exit 2; }
      model="$2"
      shift 2
    elif [[ "''${1-}" == --model=* ]]; then
      model="''${1#--model=}"
      shift
    fi
    exec ${gooseWrapper}/bin/goose --hardened-provider claude "$model" session "$@"
  '';
  gooseCodexAcp = pkgs.writeShellScriptBin "goose-codex-acp" ''
    set -euo pipefail
    model="gpt-5.4"
    if [[ "''${1-}" == "--model" ]]; then
      [[ -n "''${2-}" ]] || { echo "error: --model requires a value" >&2; exit 2; }
      model="$2"
      shift 2
    elif [[ "''${1-}" == --model=* ]]; then
      model="''${1#--model=}"
      shift
    fi
    exec ${gooseWrapper}/bin/goose --hardened-provider codex-acp "$model" session "$@"
  '';
  gooseClaudeAcp = pkgs.writeShellScriptBin "goose-claude-acp" ''
    set -euo pipefail
    model="claude-sonnet-5"
    if [[ "''${1-}" == "--model" ]]; then
      [[ -n "''${2-}" ]] || { echo "error: --model requires a value" >&2; exit 2; }
      model="$2"
      shift 2
    elif [[ "''${1-}" == --model=* ]]; then
      model="''${1#--model=}"
      shift
    fi
    exec ${gooseWrapper}/bin/goose --hardened-provider claude-acp "$model" session "$@"
  '';
  gooseChatgpt = pkgs.writeShellScriptBin "goose-chatgpt" ''
    exec ${gooseWrapper}/bin/goose --hardened-provider chatgpt gpt-5.1-codex session "$@"
  '';
in
{
  xdg.configFile."goose/config.yaml".source = gooseConfig;
  xdg.configFile."goose/custom_providers/ollama-cloud.json".source = ollamaCloudProvider;
  xdg.configFile."goose/custom_providers/opencode.json".source = opencodeProvider;

  # The wrapper shadows the package binary and supplies agenix-managed keys at
  # runtime. OpenRouter itself is a native Goose provider, so it needs no
  # additional provider JSON.
  home.packages = [
    gooseWrapper
    codexAcpSafe
    claudeAcpSafe
    gooseCodex
    gooseClaude
    gooseCodexAcp
    gooseClaudeAcp
    gooseChatgpt
  ];
}
