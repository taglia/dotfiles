{
  colorschemes.catppuccin.enable = true;
  plugins = {
    # Lazy loading
    lz-n.enable = true;

    lualine.enable = true;
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
