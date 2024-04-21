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
  };
}
