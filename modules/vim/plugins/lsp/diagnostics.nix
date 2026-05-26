{
  plugins.tiny-inline-diagnostic = {
    enable = true;
    lazyLoad.settings.event = "LspAttach";

    settings = {
      preset = "classic";
      transparent_bg = false;
      transparent_cursorline = true;

      hi = {
        error = "DiagnosticError";
        warn = "DiagnosticWarn";
        info = "DiagnosticInfo";
        hint = "DiagnosticHint";
        arrow = "NonText";
        background = "CursorLine";
        mixing_color = "Normal";
      };

      options = {
        show_all_diags_on_cursorline = false;
        multiple_diag_under_cursor = false;
        enable_on_insert = false;
        enable_on_select = false;
        use_icons_from_diagnostic = true;
        set_arrow_to_diag_color = true;

        show_source = {
          enabled = false;
          if_many = true;
        };

        throttle = 20;
        softwrap = 30;

        overflow = {
          mode = "wrap";
        };

        multilines = {
          enabled = false;
          always_show = false;
        };

        virt_texts = {
          priority = 2048;
        };
        # NOTE: deliberately no `severity` here — letting the plugin use its
        # default (all severities) avoids the awkward Lua-enum-in-nix problem.
      };
    };
  };
  opts = {
    signcolumn = "yes";
    # (or "yes:2" if you also use gitsigns/dap and want two slots)
  };

  # Configure vim.diagnostic directly via raw Lua. This is the most robust
  # way in nixvim because the severity enum is a runtime Lua value and
  # nix-side mappings for it are fragile across nixvim versions.
  extraConfigLua = ''
    vim.diagnostic.config({
      -- tiny-inline-diagnostic renders the inline messages; turn off the
      -- native virtual_text so we don't get both.
      virtual_text = false,

      underline = true,
      update_in_insert = false,
      severity_sort = true,

      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = "",
          [vim.diagnostic.severity.WARN]  = "",
          [vim.diagnostic.severity.INFO]  = "",
          [vim.diagnostic.severity.HINT]  = "󰌶",
        },
        numhl = {
          [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
          [vim.diagnostic.severity.WARN]  = "DiagnosticSignWarn",
          [vim.diagnostic.severity.INFO]  = "DiagnosticSignInfo",
          [vim.diagnostic.severity.HINT]  = "DiagnosticSignHint",
        },
      },

      float = {
        border = "solid",
        source = "if_many",
        header = "",
        prefix = "",
      },
    })
  '';

  plugins = {
    trouble = {
      enable = true;
      lazyLoad.settings.cmd = "Trouble";

      settings = {
        # Use icons from your icon provider (mini.icons or nvim-web-devicons).
        icons = { };

        # Auto-close the Trouble window when the list becomes empty
        # (e.g. you fixed all diagnostics).
        auto_close = true;

        # Don't steal focus when opening — keeps your editing flow.
        focus = false;

        # Use a bottom split by default; feels least intrusive and
        # matches the quickfix mental model.
        modes = {
          # Workspace diagnostics
          diagnostics = {
            mode = "diagnostics";
            preview = {
              type = "split";
              relative = "win";
              position = "right";
              size = 0.5;
            };
          };

          # Symbols sidebar — useful as a structural outline
          symbols = {
            mode = "symbols";
            focus = false;
            win = {
              type = "split";
              relative = "win";
              position = "right";
              size = 0.3;
            };
          };
        };
      };
    };
  };

  # Keymaps. Uses <leader>x as the "trouble/diagnostics" prefix — matches
  # the LazyVim/Folke convention which is what most tutorials assume.
  keymaps = [
    {
      mode = "n";
      key = "<leader>cd";
      action.__raw = ''
        function()
          vim.diagnostic.open_float()
        end
      '';
      options.desc = "Line Diagnostics";
    }
    {
      mode = "n";
      key = "]d";
      action.__raw = ''
        function()
          vim.diagnostic.goto_next()
        end
      '';
      options.desc = "Next Diagnostic";
    }
    {
      mode = "n";
      key = "[d";
      action.__raw = ''
        function()
          vim.diagnostic.goto_prev()
        end
      '';
      options.desc = "Previous Diagnostic";
    }
    {
      mode = "n";
      key = "]e";
      action.__raw = ''
        function()
          vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR })
        end
      '';
      options.desc = "Next Error";
    }
    {
      mode = "n";
      key = "[e";
      action.__raw = ''
        function()
          vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR })
        end
      '';
      options.desc = "Previous Error";
    }
    {
      mode = "n";
      key = "]w";
      action.__raw = ''
        function()
          vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.WARN })
        end
      '';
      options.desc = "Next Warning";
    }
    {
      mode = "n";
      key = "[w";
      action.__raw = ''
        function()
          vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.WARN })
        end
      '';
      options.desc = "Previous Warning";
    }
    {
      mode = "n";
      key = "<leader>xx";
      action = "<cmd>Trouble diagnostics toggle<cr>";
      options.desc = "Diagnostics (Trouble)";
    }
    {
      mode = "n";
      key = "<leader>xX";
      action = "<cmd>Trouble diagnostics toggle filter.buf=0<cr>";
      options.desc = "Buffer diagnostics (Trouble)";
    }
    {
      mode = "n";
      key = "<leader>cs";
      action = "<cmd>Trouble symbols toggle focus=false<cr>";
      options.desc = "Symbols (Trouble)";
    }
    {
      mode = "n";
      key = "<leader>cl";
      action = "<cmd>Trouble lsp toggle focus=false win.position=right<cr>";
      options.desc = "LSP Definitions / references / ... (Trouble)";
    }
    {
      mode = "n";
      key = "<leader>xL";
      action = "<cmd>Trouble loclist toggle<cr>";
      options.desc = "Location list (Trouble)";
    }
    {
      mode = "n";
      key = "<leader>xQ";
      action = "<cmd>Trouble qflist toggle<cr>";
      options.desc = "Quickfix list (Trouble)";
    }
    # Quick navigation between items without opening the panel
    {
      mode = "n";
      key = "[q";
      action.__raw = ''
        function()
          local trouble = package.loaded["trouble"]
          if trouble and trouble.is_open() then
            trouble.prev({ skip_groups = true, jump = true })
          else
            local ok, err = pcall(vim.cmd.cprev)
            if not ok then vim.notify(err, vim.log.levels.ERROR) end
          end
        end
      '';
      options.desc = "Previous Trouble/Quickfix item";
    }
    {
      mode = "n";
      key = "]q";
      action.__raw = ''
        function()
          local trouble = package.loaded["trouble"]
          if trouble and trouble.is_open() then
            trouble.next({ skip_groups = true, jump = true })
          else
            local ok, err = pcall(vim.cmd.cnext)
            if not ok then vim.notify(err, vim.log.levels.ERROR) end
          end
        end
      '';
      options.desc = "Next Trouble/Quickfix item";
    }
  ];
}
