{config, lib, ...}: {
  options.devtools.agent-console = {
    enable = lib.mkEnableOption "agent-console package";

    piPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Pi package used in main pane";
    };

    neovimPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Neovim package used in right pane";
    };

    zellijPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Zellij package used to launch workspace";
    };

    zellijConfigFile = lib.mkOption {
      type = lib.types.path;
      default = ../zellij/config.kdl;
      description = "Zellij config file path";
    };

    resumeMode = lib.mkOption {
      type = lib.types.enum [ "auto" "new" "resume" ];
      default = "auto";
    };

    piArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };

    rightPaneWidth = lib.mkOption {
      type = lib.types.int;
      default = 35;
    };

    startNvimCollapsed = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    projectRootMode = lib.mkOption {
      type = lib.types.enum [ "cwd" "git-root" ];
      default = "cwd";
    };
  };

  config = {
    perSystem = {
      config,
      pkgs,
      ...
    }: let
      cfg = config.devtools.agent-console;
    in lib.mkIf cfg.enable {
      packages.agent-console = pkgs.callPackage ./default.nix {
        piPackage = if cfg.piPackage != null then cfg.piPackage else config.packages.pi;
        neovimPackage = if cfg.neovimPackage != null then cfg.neovimPackage else config.packages.neovim;
        zellijPackage = if cfg.zellijPackage != null then cfg.zellijPackage else config.packages.zellij;
        inherit (cfg)
          zellijConfigFile
          resumeMode
          piArgs
          rightPaneWidth
          startNvimCollapsed
          projectRootMode;
      };
    };
  };
}
