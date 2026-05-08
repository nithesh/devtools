{config, ...}: {
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    packages.agent-console = pkgs.callPackage ./default.nix {
      piPackage = config.packages.pi;
      neovimPackage = config.packages.neovim;
      zellijPackage = config.packages.zellij;
      zellijConfigFile = ../zellij/config.kdl;
    };
  };
}
