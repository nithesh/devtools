{
  plugins.nvim-tree = {
    enable = true;
    openOnSetupFile = true;
    autoReloadOnWrite = true;
  };

  keymaps = [
    {
      key = "<C-n>";
      action = "<CMD>NvimTreeToggle<CR>";
    }
  ];
}
