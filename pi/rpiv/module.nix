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
              value = pkgs.runCommand "rpiv-${name}-package" { } ''
                cp -R ${rpivMono}/lib/node_modules/rpiv-mono/packages/${name} "$out"
                chmod -R u+w "$out"

                mkdir -p "$out/node_modules/@juicesharp"
                cp -R ${rpivMono}/lib/node_modules/rpiv-mono/packages/rpiv-config "$out/node_modules/@juicesharp/rpiv-config"
                chmod -R u+w "$out/node_modules/@juicesharp/rpiv-config"

                find "$out" -type f \( -name '*.ts' -o -name '*.js' -o -name '*.json' \) -print0 \
                  | xargs -0 sed -i \
                    -e 's#@earendil-works/pi-coding-agent#@mariozechner/pi-coding-agent#g' \
                    -e 's#@earendil-works/pi-tui#@mariozechner/pi-tui#g'
              '';
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
