{config, ...}: {
  perSystem = {
    system,
    pkgs,
    inputs',
    ...
  }: {
    packages.neovim = pkgs.callPackage ./. {
      inherit (inputs'.nixvim.legacyPackages) makeNixvimWithModule;
    };

    packages.neovim-agent-console = pkgs.callPackage ./default.nix {
      inherit (inputs'.nixvim.legacyPackages) makeNixvimWithModule;
      module = ./agent-console.nix;
    };
  };
}
