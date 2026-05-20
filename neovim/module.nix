{ config, lib, ... }:
let
  cfg = config.devtools.neovim;
in
{
  options.devtools.neovim = {
    themeModule = lib.mkOption {
      type = lib.types.nullOr lib.types.deferredModule;
      default = null;
      description = "Optional nixvim module fragment used to define colorscheme/theme.";
    };

    extraModules = lib.mkOption {
      type = lib.types.listOf lib.types.deferredModule;
      default = [ ];
      description = "Additional nixvim modules to append to the base Neovim config.";
    };
  };

  config.perSystem = {
    pkgs,
    inputs',
    ...
  }: {
    packages.neovim = pkgs.callPackage ./. {
      inherit (inputs'.nixvim.legacyPackages) makeNixvimWithModule;
      module = {
        imports =
          (lib.optional (cfg.themeModule == null) {
            colorschemes.onedark.enable = true;
          })
          ++ (lib.optional (cfg.themeModule != null) cfg.themeModule)
          ++ cfg.extraModules;
      };
    };
  };
}
