{config, ...}: {
  perSystem = {
    system,
    pkgs,
    ...
  }: {
    packages.zed = pkgs.callPackage ./. {
      settings = import ./settings.nix;
    };
  };
}
