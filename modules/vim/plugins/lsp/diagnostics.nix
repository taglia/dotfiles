{
  plugins.tiny-inline-diagnostic = {
    enable = true;

    settings = {
      preset = "simple";

      options = {
        show_source = {
          enabled = false;
        };

        use_icons_from_diagnostic = true;

        add_messages = true;

        multilines = {
          enabled = false;
        };

        show_all_diags_on_cursorline = false;

        enable_on_insert = false;

        break_line = {
          enabled = false;
        };

        overflow = {
          mode = "wrap";
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
