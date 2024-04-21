{pkgs, ...}: {
  plugins = {
    gitgutter.enable = true;
  };

  extraPlugins = with pkgs.vimPlugins; [
    lazygit-nvim
  ];
}
