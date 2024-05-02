{
  plugins = {
    lsp = {
      enable = true;
      servers = {
        lua-ls.enable = true;
        nil_ls.enable = true;
      };
      keymaps.lspBuf = {
        "gd" = "definition";
        "gD" = "references";
        "gt" = "type_definition";
        "gi" = "implementation";
        "K" = "hover";
      };
    };

    lspsaga = {
      enable = true;
      codeAction = {
        showServerName = true;
        extendGitSigns = true;
      };
      lightbulb = {
        sign = false;
      };
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>ca";
      action = "<cmd>Lspsaga code_action<CR>";
      options = {
        desc = "Code Action";
        silent = true;
      };
    }

    {
      mode = "n";
      key = "<leader>cw";
      action = "<cmd>Lspsaga outline<CR>";
      options = {
        desc = "Outline";
        silent = true;
      };
    }
  ];
}
