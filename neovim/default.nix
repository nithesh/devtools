{
  pkgs,
  makeNixvimWithModule,
  module ? {},
  ...
}:
makeNixvimWithModule {
  inherit pkgs;
  module = {
    imports = [
      module
      ./cmp.nix
      ./git.nix
      ./lsp.nix
      ./nvim-tree.nix
      ./options.nix
      ./telescope.nix
      ./toggleterm.nix
      ./treesitter.nix
      ./ui.nix
    ];
  };
}
