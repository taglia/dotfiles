{
  plugins = {
    gitsigns = {
      enable = true;

      settings = {
        signs = {
          add.text = "┃";
          change.text = "┃";
          delete.text = "_";
          topdelete.text = "‾";
          changedelete.text = "~";
          untracked.text = "┆";
        };
        signcolumn = true;
        numhl = false;
        linehl = false;
        current_line_blame = false;
        attach_to_untracked = true;
        watch_gitdir = {
          enable = true;
          follow_files = true;
        };
        on_attach = ''
          function(bufnr)
            local gitsigns = require("gitsigns")

            local function map(key, action, desc)
              vim.keymap.set("n", key, action, { buffer = bufnr, desc = desc })
            end

            map("]h", function()
              if vim.wo.diff then
                vim.cmd.normal({ "]h", bang = true })
              else
                gitsigns.nav_hunk("next")
              end
            end, "Next Git hunk")

            map("[h", function()
              if vim.wo.diff then
                vim.cmd.normal({ "[h", bang = true })
              else
                gitsigns.nav_hunk("prev")
              end
            end, "Previous Git hunk")

            map("<leader>hp", gitsigns.preview_hunk, "Preview Git hunk")
            map("<leader>hs", gitsigns.stage_hunk, "Stage Git hunk")
            map("<leader>hr", gitsigns.reset_hunk, "Reset Git hunk")
            map("<leader>hb", gitsigns.blame_line, "Blame Git line")
          end
        '';
      };
    };

    neogit = {
      enable = true;
      lazyLoad.settings = {
        cmd = "Neogit";
        keys = [
          {
            __unkeyed-1 = "<leader>gg";
            __unkeyed-3 = "<cmd>Neogit<CR>";
            desc = "Git";
            mode = "n";
          }
        ];
      };

      settings = {
        kind = "tab";
        use_default_keymaps = true;
        integrations = {
          telescope = true;
          diffview = false;
        };
      };
    };
  };
}
