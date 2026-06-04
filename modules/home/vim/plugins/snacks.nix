{
  extraConfigLuaPre =
    # lua
    ''
      vim.g.tagliavim_started_at = vim.uv.hrtime()
    '';

  plugins.snacks = {
    enable = true;

    settings = {
      bigfile.enabled = true;
      input.enabled = true;
      notifier = {
        enabled = true;
        timeout = 3000;
      };
      quickfile.enabled = true;

      dashboard = {
        enabled = true;
        width = 76;
        preset = {
          header = ''
            888                      888 d8b          888     888 d8b               
            888                      888 Y8P          888     888 Y8P               
            888                      888              888     888                   
            888888  8888b.   .d88b.  888 888  8888b.  Y88b   d88P 888 88888b.d88b.  
            888        "88b d88P"88b 888 888     "88b  Y88b d88P  888 888 "888 "88b 
            888    .d888888 888  888 888 888 .d888888   Y88o88P   888 888  888  888 
            Y88b.  888  888 Y88b 888 888 888 888  888    Y888P    888 888  888  888 
             "Y888 "Y888888  "Y88888 888 888 "Y888888     Y8P     888 888  888  888 
                                 888                                                
                            Y8b d88P                                                
                             "Y88P"                                                 
          '';
          keys = [
            {
              icon = " ";
              key = "n";
              desc = "New buffer";
              action = ":enew";
            }
            {
              icon = "󰈞 ";
              key = "s";
              desc = "Search files";
              action = ":lua Snacks.picker.files()";
            }
            {
              icon = "󰊄 ";
              key = "g";
              desc = "Grep text";
              action = ":lua Snacks.picker.grep()";
            }
            {
              icon = "󰙅 ";
              key = "e";
              desc = "File tree";
              action = ":lua Snacks.explorer()";
            }
            {
              icon = "󰅚 ";
              key = "q";
              desc = "Quit";
              action = ":qa";
            }
          ];
        };
        sections = [
          {
            section = "header";
          }
          {
            section = "keys";
            gap = 1;
            padding = 1;
          }
          {
            __raw = ''
              function()
                local started_at = vim.g.tagliavim_started_at
                local elapsed = "unknown"

                if started_at then
                  local elapsed_ms = (vim.uv.hrtime() - started_at) / 1000000
                  if elapsed_ms < 1000 then
                    elapsed = string.format("%.0fms", elapsed_ms)
                  else
                    elapsed = string.format("%.1fs", elapsed_ms / 1000)
                  end
                end

                return {
                  align = "center",
                  text = "Started in " .. elapsed,
                }
              end
            '';
          }
        ];
      };

      explorer = {
        enabled = true;
        replace_netrw = true;
      };

      lazygit.enabled = true;
      picker = {
        enabled = true;
        layout = {
          preset = "default";
        };
        # Show dotfiles and gitignored files by default. Alt-h and Alt-i still
        # toggle these categories when a narrower view is useful.
        sources = {
          files = {
            hidden = true;
            ignored = true;
          };
          grep = {
            hidden = true;
            ignored = true;
          };
          explorer = {
            hidden = true;
            ignored = true;
          };
        };
      };
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader><space>";
      action = "<cmd>lua Snacks.picker.files()<cr>";
      options.desc = "Find project files";
    }
    {
      mode = "n";
      key = "<leader>g";
      action = "<cmd>lua Snacks.picker.grep()<cr>";
      options.desc = "Grep (root dir)";
    }
    {
      mode = "n";
      key = "<leader>:";
      action = "<cmd>lua Snacks.picker.command_history()<cr>";
      options.desc = "Command History";
    }
    {
      mode = "n";
      key = "<leader>b";
      action = "<cmd>lua Snacks.picker.buffers()<cr>";
      options.desc = "+buffer";
    }
    {
      mode = "n";
      key = "<C-p>";
      action = "<cmd>lua Snacks.picker.git_files()<cr>";
      options.desc = "Search git files";
    }
    {
      mode = "n";
      key = "<leader>gc";
      action = "<cmd>lua Snacks.picker.git_log()<cr>";
      options.desc = "Commits";
    }
    {
      mode = "n";
      key = "<leader>gs";
      action = "<cmd>lua Snacks.picker.git_status()<cr>";
      options.desc = "Status";
    }
    {
      mode = "n";
      key = "<leader>sa";
      action = "<cmd>lua Snacks.picker.autocmds()<cr>";
      options.desc = "Auto Commands";
    }
    {
      mode = "n";
      key = "<leader>sb";
      action = "<cmd>lua Snacks.picker.lines()<cr>";
      options.desc = "Buffer";
    }
    {
      mode = "n";
      key = "<leader>sc";
      action = "<cmd>lua Snacks.picker.command_history()<cr>";
      options.desc = "Command History";
    }
    {
      mode = "n";
      key = "<leader>sC";
      action = "<cmd>lua Snacks.picker.commands()<cr>";
      options.desc = "Commands";
    }
    {
      mode = "n";
      key = "<leader>sD";
      action = "<cmd>lua Snacks.picker.diagnostics()<cr>";
      options.desc = "Workspace diagnostics";
    }
    {
      mode = "n";
      key = "<leader>sd";
      action = "<cmd>lua Snacks.picker.diagnostics_buffer()<cr>";
      options.desc = "Document diagnostics";
    }
    {
      mode = "n";
      key = "<leader>sh";
      action = "<cmd>lua Snacks.picker.help()<cr>";
      options.desc = "Help pages";
    }
    {
      mode = "n";
      key = "<leader>sH";
      action = "<cmd>lua Snacks.picker.highlights()<cr>";
      options.desc = "Search Highlight Groups";
    }
    {
      mode = "n";
      key = "<leader>sk";
      action = "<cmd>lua Snacks.picker.keymaps()<cr>";
      options.desc = "Keymaps";
    }
    {
      mode = "n";
      key = "<leader>sM";
      action = "<cmd>lua Snacks.picker.man()<cr>";
      options.desc = "Man pages";
    }
    {
      mode = "n";
      key = "<leader>sm";
      action = "<cmd>lua Snacks.picker.marks()<cr>";
      options.desc = "Jump to Mark";
    }
    {
      mode = "n";
      key = "<leader>so";
      action = "<cmd>options<cr>";
      options.desc = "Options";
    }
    {
      mode = "n";
      key = "<leader>sR";
      action = "<cmd>lua Snacks.picker.resume()<cr>";
      options.desc = "Resume";
    }
    {
      mode = "n";
      key = "<leader>uC";
      action = "<cmd>lua Snacks.picker.colorschemes()<cr>";
      options.desc = "Colorscheme preview";
    }
    {
      mode = "n";
      key = "<leader>e";
      action = "<cmd>lua Snacks.explorer()<cr>";
      options.desc = "Open file explorer";
    }
    {
      mode = "n";
      key = "<leader>fe";
      action = "<cmd>lua Snacks.explorer()<cr>";
      options.desc = "File browser";
    }
    {
      mode = "n";
      key = "<leader>fE";
      action = "<cmd>lua Snacks.explorer({ cwd = vim.fn.expand('%:p:h') })<cr>";
      options.desc = "File browser";
    }
  ];
}
