{
  lib,
  ...
}:

let
  button =
    shortcut: label: command:
    {
      type = "button";
      val = label;
      on_press.__raw = ''
        function()
          vim.cmd(${builtins.toJSON command})
        end
      '';
      opts = {
        align_shortcut = "right";
        cursor = 3;
        hl_shortcut = "Keyword";
        keymap = [
          "n"
          shortcut
          "<cmd>${command}<cr>"
          {
            noremap = true;
            nowait = true;
            silent = true;
          }
        ];
        position = "center";
        shortcut = shortcut;
        width = 48;
      };
    };
in
{
  extraConfigLuaPre =
    # lua
    ''
      vim.g.tagliavim_started_at = vim.uv.hrtime()
    '';

  plugins.alpha.enable = true;

  plugins.alpha.settings = {
    layout = [
      {
        type = "padding";
        val = 2;
      }
      {
        opts = {
          hl = "Type";
          position = "center";
        };
        type = "text";
        val = [
          "████████╗ █████╗  ██████╗ ██╗     ██╗ █████╗ ██╗   ██╗██╗███╗   ███╗"
          "╚══██╔══╝██╔══██╗██╔════╝ ██║     ██║██╔══██╗██║   ██║██║████╗ ████║"
          "   ██║   ███████║██║  ███╗██║     ██║███████║██║   ██║██║██╔████╔██║"
          "   ██║   ██╔══██║██║   ██║██║     ██║██╔══██║╚██╗ ██╔╝██║██║╚██╔╝██║"
          "   ██║   ██║  ██║╚██████╔╝███████╗██║██║  ██║ ╚████╔╝ ██║██║ ╚═╝ ██║"
          "   ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝╚═╝     ╚═╝"

        ];
      }
      {
        type = "padding";
        val = 2;
      }
      {
        type = "padding";
        val = 1;
      }
      {
        opts = {
          spacing = 1;
        };
        type = "group";
        val = [
          (button "n" "  New buffer" "enew")
          (button "s" "󰈞  Search files" "Telescope find_files")
          (button "g" "󰊄  Grep text" "Telescope live_grep")
          (button "e" "󰙅  File tree" "Neotree toggle")
          (button "q" "󰅚  Quit" "qa")
        ];
      }
      {
        type = "padding";
        val = 1;
      }
      {
        opts = {
          hl = "Keyword";
          position = "center";
        };
        type = "text";
        val.__raw = ''
          function()
            local started_at = vim.g.tagliavim_started_at
            if not started_at then
              return "Started"
            end

            local elapsed_ms = (vim.uv.hrtime() - started_at) / 1000000
            local elapsed

            if elapsed_ms < 1000 then
              elapsed = string.format("%.0fms", elapsed_ms)
            else
              elapsed = string.format("%.1fs", elapsed_ms / 1000)
            end

            return "Started in " .. elapsed
          end
        '';
      }
    ];
  };
}
