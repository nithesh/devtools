{
  plugins.telescope = {
    enable = true;
    extensions.file-browser = {
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
      key = "<leader>fb";
      action = "<CMD>Telescope file_browser path=%:p:h select_buffer=true<CR>";
    }
  ];
}
