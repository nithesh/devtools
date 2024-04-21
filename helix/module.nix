{config, ...}: {
  perSystem = {
    system,
    pkgs,
    ...
  }: {
    packages.helix = pkgs.callPackage ./. {
      config = import ./config.nix;
    };
  };
}
