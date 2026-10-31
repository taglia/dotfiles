{ pkgs, ... }:
{
  plugins = {
    lsp-lines = {
      enable = true;
    };
    helm = {
      enable = true;
    };
    lsp = {
      enable = true;
      inlayHints = true;
      servers = {
        bashls = {
          enable = true;
        };
        clangd = {
          enable = true;
        };
        cssls = {
          enable = true;
        };
        fish_lsp = {
          enable = true;
        };
        gopls = {
          enable = true;
        };
        helm_ls = {
          enable = true;
          extraOptions = {
            settings = {
              "helm_ls" = {
                yamlls = {
                  path = "${pkgs.yaml-language-server}/bin/yaml-language-server";
                };
              };
            };
          };
        };
        html = {
          enable = true;
        };
        jsonls = {
          enable = true;
        };
        lua_ls = {
          enable = true;
        };
        marksman = {
          enable = true;
          # BUILD FIX (2026-10-31): marksman's default runtime is the
          # source-built dotnet 9, which Hydra has not cached for
          # aarch64-darwin since the 9.0.22 bump, so it compiled the entire
          # .NET SDK locally (hours). The prebuilt runtime is cached on all
          # platforms and functionally identical for marksman. Drop the
          # override once nixpkgs#dotnetCorePackages.runtime_9_0 substitutes
          # on aarch64-darwin again (see AGENTS.md, "Pending upstream checks").
          package = pkgs.marksman.override {
            dotnetCorePackages = pkgs.dotnetCorePackages // {
              runtime_9_0 = pkgs.dotnetCorePackages.runtime_9_0-bin;
            };
          };
        };
        nil_ls = {
          enable = true;
        };
        pyright = {
          enable = true;
        };
        ruby_lsp = {
          enable = true;
        };
        rust_analyzer = {
          enable = true;
          installCargo = false;
          installRustc = false;
        };
        sqls = {
          enable = true;
        };
        taplo = {
          enable = true;
        };
        terraformls = {
          enable = true;
        };
        ts_ls = {
          enable = true;
        };
        yamlls = {
          enable = true;
          extraOptions = {
            settings = {
              yaml = {
                schemas = {
                  kubernetes = "*.yaml";
                  "https://json.schemastore.org/github-workflow" = ".github/workflows/*";
                  "https://json.schemastore.org/github-action" = ".github/action.{yml,yaml}";
                  "https://json.schemastore.org/ansible-stable-2.9" = "roles/tasks/*.{yml,yaml}";
                  "https://json.schemastore.org/kustomization" = "kustomization.{yml,yaml}";
                  "https://json.schemastore.org/ansible-playbook" = "*play*.{yml,yaml}";
                  "https://json.schemastore.org/chart" = "Chart.{yml,yaml}";
                  "https://json.schemastore.org/dependabot-v2" = ".github/dependabot.{yml,yaml}";
                  "https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json" =
                    "*docker-compose*.{yml,yaml}";
                  "https://raw.githubusercontent.com/argoproj/argo-workflows/master/api/jsonschema/schema.json" =
                    "*flow*.{yml,yaml}";
                };
              };
            };
          };
        };
      };

      keymaps = {
        silent = true;
        lspBuf = {
          gd = {
            action = "definition";
            desc = "Goto Definition";
          };
          gr = {
            action = "references";
            desc = "Goto References";
          };
          gD = {
            action = "declaration";
            desc = "Goto Declaration";
          };
          gI = {
            action = "implementation";
            desc = "Goto Implementation";
          };
          gT = {
            action = "type_definition";
            desc = "Type Definition";
          };
          K = {
            action = "hover";
            desc = "Hover";
          };
          "<leader>cw" = {
            action = "workspace_symbol";
            desc = "Workspace Symbol";
          };
          "<leader>cr" = {
            action = "rename";
            desc = "Rename";
          };
        };
      };
    };
  };
  extraPlugins = with pkgs.vimPlugins; [
    ansible-vim
  ];

  # Floating-window borders: hover/signature-help borders are handled via
  # vim.o.winborder (Neovim 0.11+ ignores vim.lsp.handlers overrides), and the
  # diagnostic float border is configured in ./diagnostics.nix.
  extraConfigLua = ''
    vim.o.winborder = "rounded"

    require('lspconfig.ui.windows').default_options = {
      border = "rounded"
    }
  '';
}
