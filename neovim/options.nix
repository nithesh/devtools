{
  config = {
    opts = {
      number = true;
      relativenumber = true;

      incsearch = true;
      ignorecase = true;
      smartcase = true;

      autoindent = true;
      smartindent = true;
      expandtab = true;
      shiftwidth = 2;
      tabstop = 2;

      termguicolors = true;
    };

    extraConfigLua = ''
      vim.api.nvim_create_autocmd("VimResized", {
        callback = function()
          local has_diff = false
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.wo[win].diff then
              has_diff = true
              break
            end
          end

          if has_diff then
            vim.cmd("wincmd =")
          end
        end,
      })
    '';

    vimAlias = true;
  };
}
