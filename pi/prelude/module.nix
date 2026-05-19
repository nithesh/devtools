{ config, lib, ... }:
let
  defaultExtensions = [
    ./extensions/mode.ts
    ./extensions/status.ts
  ];

  defaultPrompts = [ ];

  defaultSkills = [ ];

  cfg = config.devtools.pi.prelude;
in
{
  options.devtools.pi.prelude = {
    enable = lib.mkEnableOption "pi-prelude wrapped Pi package";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Base pi package to wrap (defaults to pi-unwrapped)";
    };

    extensions = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = defaultExtensions;
      description = "Prelude extension paths";
    };

    prompts = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = defaultPrompts;
      description = "Prelude prompt template paths";
    };

    skills = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = defaultSkills;
      description = "Prelude skill paths";
    };

    extraArgs = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra args passed to pi/default.nix wrapper";
    };
  };

  config = {
    perSystem = { config, pkgs, ... }:
      lib.mkIf cfg.enable {
        packages.pi-prelude = pkgs.callPackage ../default.nix (
          {
            pi-unwrapped = if cfg.package != null then cfg.package else config.packages.pi-unwrapped;
            extensions = cfg.extensions;
            prompts = cfg.prompts;
            skills = cfg.skills;
          }
          // cfg.extraArgs
        );
      };
  };
}
