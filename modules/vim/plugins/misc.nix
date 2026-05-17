{
  colorschemes.catppuccin.enable = true;
  plugins = {
    # Lazy loading
    lz-n.enable = true;

    lualine.enable = true;
    which-key.enable = true;
    telescope.enable = true;
    web-devicons.enable = true;

    oil = {
      enable = true;
      lazyLoad.settings.cmd = "Oil";
    };

    nvim-tree = {
      enable = true;
      lazyLoad.settings.cmd = [
        "NvimTreeToggle"
        "NvimTreeOpen"
        "NvimTreeFindFile"
      ];
    };

    noice = {
      enable = true;
      lazyLoad.settings = {
        event = "CmdlineEnter";
      };
    };
    notify.enable = true;
  };
}
