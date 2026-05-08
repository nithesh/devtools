{config, ...}: {
  perSystem = {
    pkgs,
    ...
  }: {
    packages.zellij = pkgs.callPackage ./. {};
  };
}
