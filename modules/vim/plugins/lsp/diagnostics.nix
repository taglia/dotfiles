{
  plugins.tiny-inline-diagnostic = {
    enable = true;

    settings = {
      preset = "modern";
      options = {
        multilines = {
          enabled = true;
          always_show = false;
        };
        options = {
          use_icons_from_diagnostic = true;
        };
        virt_texts = {
          priority = 2048;
        };
        # Display related diagnostics from LSP relatedInformation
        show_related = {
          enabled = true;
          max_count = 3;
        };
        overflow = {
          mode = "wrap";
          padding = 0;
        };
      };
    };
  };

  diagnostic.settings = {
    virtual_text = false;
    underline = true;
    signs = true;
    severity_sort = true;
    update_in_insert = false;
  };
  plugins.trouble.enable = true;
}
