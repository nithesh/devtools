{config, ...}: {
  perSystem = {
    config,
    pkgs,
    inputs',
    ...
  }: {
    packages.agent-console = pkgs.callPackage ./default.nix {
      piPackage = config.packages.pi;
      neovimPackage = pkgs.callPackage ../neovim/default.nix {
        inherit (inputs'.nixvim.legacyPackages) makeNixvimWithModule;
        module = ./neovim.nix;
      };
      zellijPackage = config.packages.zellij;
      zellijConfigFile = ../zellij/config.kdl;
      piExtensions = [ ./extensions/nvim-rpc.ts ];
    };
  };
}
