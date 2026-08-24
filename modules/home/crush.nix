# Global configuration for Crush (charmbracelet/crush). Only the global
# ~/.config/crush/crush.json is managed here; Crush keeps model selection and
# session state in its data directory, so the Nix store symlink stays
# read-only. Project-level crush.json files still merge on top of this one.
#
# API keys never live in this file or the store: providers expand them at
# startup with shell commands that read the agenix-deployed symlinks under
# ~/.local/share/agenix/ directly, so no environment variables need to reach
# Crush; the nono profile only needs a narrow read_file grant per key file.
{
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:

let
  json = pkgs.formats.json { };

  aiProviders = import ../../lib/ai-providers.nix;
  secretsRuntime = import ../../lib/secrets-runtime.nix;
  inherit (aiProviders) defaultModels;

  # Startup shell expansion reading an agenix-deployed secret; see the header
  # comment. The path constant is shared with profiles/private.nix through
  # lib/secrets-runtime.nix.
  secretExpand = name: ''$(cat "${secretsRuntime.shellFile name}")'';

  # Wrapper that blocks on any local Crush config files (crushrc or
  # crush.json) found between cwd and the git root. crushrc files are
  # executed as shell scripts (arbitrary code); crush.json files merge
  # over the global config and can add providers, MCPs, hooks, or widen
  # permissions. CRUSH_ALLOW_LOCAL=1 bypasses the block for trusted
  # repos. nono is invoked manually when sandboxing is needed.
  crushWrapper = pkgs.writeShellScriptBin "crush" ''
    set -euo pipefail

    if [[ "''${CRUSH_ALLOW_LOCAL:-}" != "1" ]]; then
      root=""
      if root_str="$(git rev-parse --show-toplevel 2>/dev/null)"; then
        root="$root_str"
      fi
      dir="$(pwd)"
      while [[ "$dir" != "/" && ( "$root" == "" || "$dir" != "$root" ) ]]; do
        for f in .crushrc crushrc .crush.json crush.json; do
          if [[ -f "$dir/$f" ]]; then
            echo "error: refusing to start Crush: local config found at $dir/$f" >&2
            echo "hint: inspect the file, then set CRUSH_ALLOW_LOCAL=1 if you trust it" >&2
            exit 1
          fi
        done
        dir="$(dirname "$dir")"
      done
      if [[ -n "$root" ]]; then
        for f in .crushrc crushrc .crush.json crush.json; do
          if [[ -f "$root/$f" ]]; then
            echo "error: refusing to start Crush: local config found at $root/$f" >&2
            echo "hint: inspect the file, then set CRUSH_ALLOW_LOCAL=1 if you trust it" >&2
            exit 1
          fi
        done
      fi
    fi

    exec ${pkgs-unstable.crush}/bin/crush "$@"
  '';

  # Crush's model schema, filled from the shared catalog in
  # lib/ai-providers.nix; the ids exposed here are chosen per tool.
  ollamaModel =
    id:
    let
      m = aiProviders.ollamaCloud.models.${id};
    in
    {
      inherit id;
      inherit (m) name;
      context_window = m.context;
      default_max_tokens = 65536;
      can_reason = true;
    }
    // lib.optionalAttrs (m ? attachments) { supports_attachments = m.attachments; }
    // lib.optionalAttrs (m ? cost) {
      cost_per_1m_in = m.cost.input;
      cost_per_1m_out = m.cost.output;
      cost_per_1m_in_cached = m.cost.cacheRead;
      cost_per_1m_out_cached = m.cost.cacheWrite;
    };

  crushConfig = json.generate "crush.json" {
    "$schema" = "https://charm.land/crush.json";

    options = {
      tui = {
        transparent = true;
        compact_mode = true;
      };

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
        model = defaultModels.large;
        provider = "ollama-cloud";
      };
      small = {
        model = defaultModels.small;
        provider = "ollama-cloud";
      };
    };

    providers = {
      ollama-cloud = {
        inherit (aiProviders.ollamaCloud) name;
        type = "openai-compat";
        base_url = aiProviders.ollamaCloud.baseUrl;
        api_key = secretExpand "pi_ollama_api_key";
        # Only the explicitly listed models below; no /v1/models discovery
        # against the cloud endpoint.
        discover_models = false;
        models = map ollamaModel [
          "glm-5.2"
          "kimi-k3"
          "deepseek-v4-pro"
          "minimax-m3"
        ];
      };

      openrouter = {
        name = "OpenRouter";
        type = "openai-compat";
        api_key = secretExpand "openrouter_api_key";
        base_url = "https://openrouter.ai/api/v1";
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
      # Crush expects the catalog's models endpoint here, not the bare API
      # root shared with the other tools — hence the /models suffix.
      opencode-zen = {
        base_url = "${aiProviders.opencodeZen.baseUrl}/models";
        api_key = secretExpand "opencode_zen_api_key";
      };
    };
  };
  # nono base profile: sets the security posture (deny credentials, open
  # network, readwrite workdir) but leaves filesystem grants empty. The
  # user-authored draft profile (outside HM, writable by nono's save prompt)
  # extends this and accumulates grants through real usage. When the draft
  # stabilizes, promote its grants here to enforce them declaratively.
  nonoBaseProfile = json.generate "crush-base.json" {
    extends = "default";
    meta = {
      name = "crush-base";
      description = "Security baseline for Crush; extend with per-machine grants";
    };
    groups.include = [ "deny_credentials" ];
    workdir.access = "readwrite";
    network.block = false;
  };
in
{
  xdg.configFile."crush/crush.json".source = crushConfig;
  xdg.configFile."nono/profiles/crush-base.json".source = nonoBaseProfile;

  # The wrapper shadows the real crush binary via PATH precedence to block
  # unreviewed project-local config (see its comment above). It does NOT
  # sandbox: nono is invoked manually with the base profile above when
  # sandboxing is needed.
  home.packages = [ crushWrapper ];
}
