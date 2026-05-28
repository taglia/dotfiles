{
  plugins.blink-cmp = {
    enable = true;
    setupLspCapabilities = true;

    settings = {
      keymap = {
        preset = "default";

        "<C-Space>" = [
          "show"
          "show_documentation"
          "hide_documentation"
        ];
        "<C-j>" = [
          "select_next"
          "fallback"
        ];
        "<C-k>" = [
          "select_prev"
          "fallback"
        ];
        "<C-Tab>" = [
          "select_next"
          "fallback"
        ];
        "<C-e>" = [ "hide" ];
        "<C-b>" = [
          "scroll_documentation_up"
          "fallback"
        ];
        "<C-f>" = [
          "scroll_documentation_down"
          "fallback"
        ];
        "<C-CR>" = [
          "select_and_accept"
          "fallback"
        ];
        "<S-CR>" = [
          "select_and_accept"
          "fallback"
        ];
      };

      completion = {
        documentation = {
          auto_show = false;
          window.border = "solid";
        };
        ghost_text.enabled = false;
        list.max_items = 30;
        menu.border = "solid";
      };

      sources = {
        default = [
          "lsp"
          "path"
          "snippets"
          "buffer"
        ];
        providers = {
          buffer = {
            min_keyword_length = 3;
          };
          path = {
            min_keyword_length = 3;
          };
          snippets = {
            min_keyword_length = 3;
          };
        };
      };
    };
  };
}
