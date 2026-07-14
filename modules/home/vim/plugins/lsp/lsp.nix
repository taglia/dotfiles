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
                  "http://json.schemastore.org/github-workflow" = ".github/workflows/*";
                  "http://json.schemastore.org/github-action" = ".github/action.{yml,yaml}";
                  "http://json.schemastore.org/ansible-stable-2.9" = "roles/tasks/*.{yml,yaml}";
                  "http://json.schemastore.org/kustomization" = "kustomization.{yml,yaml}";
                  "http://json.schemastore.org/ansible-playbook" = "*play*.{yml,yaml}";
                  "http://json.schemastore.org/chart" = "Chart.{yml,yaml}";
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
