{ config, lib, ... }:
let
  cfg = config.devtools.pi.rpiv;
in
{
  options.devtools.pi.rpiv = {
    enable = lib.mkEnableOption "RPIV mono packages for Pi";
    packages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "rpiv-web-tools" ];
      description = "Package names under rpiv-mono/packages to expose and auto-register in .pi/settings.json.";
    };
  };

  config = {
    perSystem = { pkgs, ... }:
      lib.mkIf cfg.enable (
        let
          rpivMono = pkgs.callPackage ./rpiv-mono.nix { };
          rpivPackages = lib.listToAttrs (map (
            name:
            {
              name = "rpiv-${name}";
              value = pkgs.symlinkJoin {
                name = "rpiv-${name}-package";
                paths = [ "${rpivMono}/lib/node_modules/rpiv-mono/packages/${name}" ];
              };
            }
          ) cfg.packages);
          rpivExtensionDrvs = map (name: rpivPackages."rpiv-${name}") cfg.packages;
        in
        {
          packages = { rpiv-mono = rpivMono; } // rpivPackages;
          devtools.pi.packageExtensions = rpivExtensionDrvs;
        }
      );

    devtools.pi.managedSettings = lib.mkIf cfg.enable {
      enable = true;
    };
  };
}
