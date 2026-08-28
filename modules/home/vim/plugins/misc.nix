{ pkgs, ... }:
let
  inherit (import ../../../../lib/catppuccin.nix) palette;

  # Wraps cell content of pipe tables wider than the window; render-markdown
  # cannot reflow them (MeanderingProgrammer/render-markdown.nvim#616). Not in
  # nixpkgs, so built from source.
  markdown-table-wrap = pkgs.vimUtils.buildVimPlugin {
    pname = "markdown-table-wrap.nvim";
    version = "2026-08-23";
    src = pkgs.fetchFromGitHub {
      owner = "ice345";
      repo = "markdown-table-wrap.nvim";
      rev = "c9febfeb82770086f06ed4c2d597651a4b76d5d6";
      hash = "sha256-wTuwvGsKGsuJLgl9/eXO/3kEuGf6shVPDdqQp3EFWs0=";
    };
  };
in
{
  extraPlugins = [ markdown-table-wrap ];
  extraConfigLua = ''
    require("markdown-table-wrap").setup({
      -- Render wrapped tables in place instead of opening the full-document
      -- reader view; render-markdown keeps handling everything else.
      preview_mode = "inline",
    })
  '';

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
            fg = "#${palette.yellow}";
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

    render-markdown = {
      enable = true;
      lazyLoad.settings.ft = "markdown";
      # Tables are rendered by markdown-table-wrap.nvim instead, which can
      # wrap cells of tables wider than the window.
      settings.pipe_table.enabled = false;
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
