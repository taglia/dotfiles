{
  extraConfigLuaPre = ''
    -- Neovim 0.12 installs a default <C-l> redraw/nohlsearch mapping that
    -- conflicts with vim-tmux-navigator's right-pane binding.
    pcall(vim.keymap.del, "n", "<C-l>")
  '';

  colorschemes.catppuccin.enable = true;
  plugins = {
    # Lazy loading
    lz-n.enable = true;

    lualine = {
      enable = true;
      settings.sections.lualine_x = [
        {
          __unkeyed-1.__raw = ''
            function()
              local register = vim.fn.reg_recording()
              if register == "" then
                return ""
              end
              return "REC @" .. register
            end
          '';
          color = {
            fg = "#f9e2af";
            gui = "bold";
          };
        }
        "encoding"
        "fileformat"
        "filetype"
      ];
    };
    tmux-navigator = {
      enable = true;
      settings.no_wrap = 1;
    };
    vim-surround.enable = true;
    which-key.enable = true;
    web-devicons.enable = true;

    oil = {
      enable = true;
      lazyLoad.settings.cmd = "Oil";
    };

    noice = {
      enable = true;
      lazyLoad.settings = {
        event = "CmdlineEnter";
      };
      settings.notify.enabled = false;
    };
  };
}
