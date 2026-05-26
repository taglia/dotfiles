{ inputs, ... }:
{
  programs.nixvim = {
    enable = true;
    nixpkgs.source = inputs.nixpkgs;

    imports = [
      ./keymaps.nix
      ./plugins/misc.nix
      ./settings.nix
      ./plugins/undotree.nix
      ./plugins/treesitter.nix
      ./plugins/snacks.nix
      ./plugins/git.nix

      # LSP
      ./plugins/lsp/lsp.nix
      ./plugins/lsp/fidget.nix
      ./plugins/lsp/conform.nix
      ./plugins/lsp/diagnostics.nix

      # Completion
      ./plugins/cmp/cmp.nix
      ./plugins/cmp/autopairs.nix
      ./plugins/cmp/schemastore.nix
    ];

  };
}
