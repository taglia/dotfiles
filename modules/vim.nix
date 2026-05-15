{ pkgs, config, ... }:

{
  programs.nixvim = {
    enable = true;

    colorschemes.catppuccin.enable = true;
    plugins.lualine.enable = true;
    plugins.which-key.enable = true;
    plugins.telescope.enable = true;
    plugins.web-devicons.enable = true;

    plugins.treesitter = {
      enable = true;
      settings = {
        highlight.enable = true;
        indent.enable = true;
        folding.enable = true;
      };
      grammarPackages = with config.programs.nixvim.plugins.treesitter.package.builtGrammars; [
        bash
        fish
        go
        rust
        json
        lua
        make
        markdown
        nix
        python
        regex
        toml
        vim
        vimdoc
        xml
        yaml
      ];
    };

    plugins.nvim-tree.enable = true;
    plugins.oil.enable = true;

    extraConfigLua = ''
    vim.g.clipboard = {
      name = 'OSC 52',
      copy = {
        ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
        ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
      },
      paste = {
        ['+'] = require('vim.ui.clipboard.osc52').paste('+'),
        ['*'] = require('vim.ui.clipboard.osc52').paste('*'),
      },
    }

    vim.opt.clipboard = 'unnamedplus'
    '';

    globals.mapleader = " ";

    opts = {
      expandtab = true;

      tabstop = 2;
      shiftwidth = 2;
      softtabstop = 2;

      smartindent = true;
      smarttab = true;
    };
  };
}
