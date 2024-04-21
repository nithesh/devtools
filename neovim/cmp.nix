{
  plugins.nvim-cmp = {
    enable = true;
    sources = [
      {name = "nvim_lsp";}
      {name = "path";}
      {name = "buffer";}
    ];

    mapping = {
      "<C-n>" = "cmp.mapping.select_next_item()";
      "<C-p>" = "cmp.mapping.select_prev_item()";
      "<C-j>" = "cmp.mapping.select_next_item()";
      "<C-k>" = "cmp.mapping.select_prev_item()";
      "<C-d>" = "cmp.mapping.scroll_docs(-4)";
      "<C-f>" = "cmp.mapping.scroll_docs(4)";
      "<C-Space>" = "cmp.mapping.complete()";
      "<C-e>" = "cmp.mapping.close()";
      "<CR>" = "cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Insert, select = true })";
    };
  };
}