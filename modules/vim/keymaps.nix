{
  globals.mapleader = " ";

  keymaps = [
    {
      mode = [
        "n"
        "x"
      ];
      key = "j";
      action = "v:count == 0 ? 'gj' : 'j'";
      options = {
        expr = true;
        silent = true;
      };
    }
    {
      mode = [
        "n"
        "x"
      ];
      key = "<Down>";
      action = "v:count == 0 ? 'gj' : 'j'";
      options = {
        expr = true;
        silent = true;
      };
    }
    {
      mode = [
        "n"
        "x"
      ];
      key = "k";
      action = "v:count == 0 ? 'gk' : 'k'";
      options = {
        expr = true;
        silent = true;
      };
    }
    {
      mode = [
        "n"
        "x"
      ];
      key = "<Up>";
      action = "v:count == 0 ? 'gk' : 'k'";
      options = {
        expr = true;
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<C-h>";
      action = "<C-w>h";
      options = {
        desc = "Go to Left Window";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<C-j>";
      action = "<C-w>j";
      options = {
        desc = "Go to Lower Window";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<C-k>";
      action = "<C-w>k";
      options = {
        desc = "Go to Upper Window";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<C-l>";
      action = "<C-w>l";
      options = {
        desc = "Go to Right Window";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<C-w>H";
      action = "<cmd>vertical resize -2<CR>";
      options.silent = true;
    }
    {
      mode = "n";
      key = "<C-w>L";
      action = "<cmd>vertical resize +2<CR>";
      options.silent = true;
    }
    {
      mode = "n";
      key = "<C-w>J";
      action = "<cmd>resize +2<CR>";
      options.silent = true;
    }
    {
      mode = "n";
      key = "<C-w>K";
      action = "<cmd>resize -2<CR>";
      options.silent = true;
    }
    {
      mode = [
        "i"
        "n"
      ];
      key = "<esc>";
      action = "<cmd>noh<cr><esc>";
      options = {
        desc = "Escape and Clear hlsearch";
      };
    }
    {
      mode = "n";
      key = "n";
      action = "'Nn'[v:searchforward].'zv'";
      options = {
        expr = true;
        desc = "Next Search Result";
      };
    }
    {
      mode = "x";
      key = "n";
      action = "'Nn'[v:searchforward]";
      options = {
        expr = true;
        desc = "Next Search Result";
      };
    }
    {
      mode = "o";
      key = "n";
      action = "'Nn'[v:searchforward]";
      options = {
        expr = true;
        desc = "Next Search Result";
      };
    }
    {
      mode = "n";
      key = "N";
      action = "'nN'[v:searchforward].'zv'";
      options = {
        expr = true;
        desc = "Prev Search Result";
      };
    }
    {
      mode = "x";
      key = "N";
      action = "'nN'[v:searchforward]";
      options = {
        expr = true;
        desc = "Prev Search Result";
      };
    }
    {
      mode = "o";
      key = "N";
      action = "'nN'[v:searchforward]";
      options = {
        expr = true;
        desc = "Prev Search Result";
      };
    }
    {
      mode = "n";
      key = "<leader>cd";
      action = "vim.diagnostic.open_float";
      options = {
        desc = "Line Diagnostics";
      };
    }
    {
      mode = "n";
      key = "]d";
      action = "diagnostic_goto(true)";
      options = {
        desc = "Next Diagnostic";
      };
    }
    {
      mode = "n";
      key = "[d";
      action = "diagnostic_goto(false)";
      options = {
        desc = "Prev Diagnostic";
      };
    }
    {
      mode = "n";
      key = "]e";
      action = "diagnostic_goto(true 'ERROR')";
      options = {
        desc = "Next Error";
      };
    }
    {
      mode = "n";
      key = "[e";
      action = "diagnostic_goto(false 'ERROR')";
      options = {
        desc = "Prev Error";
      };
    }
    {
      mode = "n";
      key = "]w";
      action = "diagnostic_goto(true 'WARN')";
      options = {
        desc = "Next Warning";
      };
    }
    {
      mode = "n";
      key = "[w";
      action = "diagnostic_goto(false 'WARN')";
      options = {
        desc = "Prev Warning";
      };
    }
    {
      mode = "n";
      key = "<leader>qq";
      action = "<cmd>qa<cr>";
      options = {
        desc = "Quit All";
      };
    }
    {
      mode = "t";
      key = "<esc><esc>";
      action = "<c-\\><c-n>";
      options = {
        desc = "Enter Normal Mode";
      };
    }
    {
      mode = "t";
      key = "<C-h>";
      action = "<cmd>wincmd h<cr>";
      options = {
        desc = "Go to Left Window";
      };
    }
    {
      mode = "t";
      key = "<C-j>";
      action = "<cmd>wincmd j<cr>";
      options = {
        desc = "Go to Lower Window";
      };
    }
    {
      mode = "t";
      key = "<C-k>";
      action = "<cmd>wincmd k<cr>";
      options = {
        desc = "Go to Upper Window";
      };
    }
    {
      mode = "t";
      key = "<C-l>";
      action = "<cmd>wincmd l<cr>";
      options = {
        desc = "Go to Right Window";
      };
    }
    {
      mode = "n";
      key = "<leader>ww";
      action = "<C-W>p";
      options = {
        desc = "Other Window";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>wd";
      action = "<C-W>c";
      options = {
        desc = "Delete Window";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>w-";
      action = "<C-W>s";
      options = {
        desc = "Split Window Below";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>w|";
      action = "<C-W>v";
      options = {
        desc = "Split Window Right";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>-";
      action = "<C-W>s";
      options = {
        desc = "Split Window Below";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<leader>|";
      action = "<C-W>v";
      options = {
        desc = "Split Window Right";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<leader><tab>l";
      action = "<cmd>tablast<cr>";
      options = {
        desc = "Last Tab";
      };
    }
    {
      mode = "n";
      key = "<leader><tab>f";
      action = "<cmd>tabfirst<cr>";
      options = {
        desc = "First Tab";
      };
    }
    {
      mode = "n";
      key = "<leader><tab><tab>";
      action = "<cmd>tabnew<cr>";
      options = {
        desc = "New Tab";
      };
    }
    {
      mode = "n";
      key = "<leader><tab>]";
      action = "<cmd>tabnext<cr>";
      options = {
        desc = "Next Tab";
      };
    }
    {
      mode = "n";
      key = "<leader><tab>d";
      action = "<cmd>tabclose<cr>";
      options = {
        desc = "Close Tab";
      };
    }
    {
      mode = "n";
      key = "<leader><tab>[";
      action = "<cmd>tabprevious<cr>";
      options = {
        desc = "Previous Tab";
      };
    }
  ];
}
