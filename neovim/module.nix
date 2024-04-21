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
  };
}
