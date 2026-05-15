{
  programs.nixvim = {
    enable = true;

    imports = [
      ./keymaps.nix
      ./plugins/misc.nix
      ./settings.nix
      ./plugins/undotree.nix
      ./plugins/treesitter.nix
      ./plugins/telescope.nix
      ./plugins/alpha.nix
      ./plugins/neo-tree.nix

      # LSP
      ./plugins/lsp/lsp.nix
      ./plugins/lsp/fidget.nix
      ./plugins/lsp/conform.nix
      ./plugins/lsp/diagnostics.nix

      # Completion
      ./plugins/cmp/cmp.nix
      ./plugins/cmp/lspkind.nix
      ./plugins/cmp/autopairs.nix
      ./plugins/cmp/schemastore.nix
    ];

  };
}
