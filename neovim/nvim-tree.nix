{
  plugins.nvim-tree = {
    enable = true;
    openOnSetupFile = true;
    settings.auto_reload_on_write = true;
  };

  keymaps = [
    {
      key = "<C-n>";
      action = "<CMD>NvimTreeToggle<CR>";
    }
  ];
}
