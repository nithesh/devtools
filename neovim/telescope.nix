{
  plugins.telescope = {
    enable = true;
    extensions.file_browser = {
      enable = true;
    };
    keymaps = {
      "<leader>ff" = "find_files";
      "<leader>fg" = "live_grep";
      "<leader>fb" = "buffers";
      "<leader>fh" = "help_tags";
    };
  };

  keymaps = [
    {
      key = "<leader>cf";
      action = "<CMD>Telescope file_browser path=%:p:h select_buffer=true<CR>";
    }
  ];
}
