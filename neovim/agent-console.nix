{pkgs, ...}: {
  extraPlugins = with pkgs.vimPlugins; [
    diffview-nvim
  ];

  keymaps = [
    {
      key = "<leader>gd";
      action = "<cmd>DiffviewOpen<cr>";
    }
    {
      key = "<leader>gD";
      action = "<cmd>DiffviewClose<cr>";
    }
    {
      key = "<leader>gg";
      action = "<cmd>LazyGit<cr>";
    }
    {
      key = "<leader>e";
      action = "<cmd>NvimTreeToggle<cr>";
    }
  ];
}
