# Home Manager module for Pi
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.pi;
in {
  meta.maintainers = [];

  options.programs.pi = {
    enable = lib.mkEnableOption "Pi coding agent";

    package = lib.mkOption {
      type = lib.types.package;
      default = config.packages.pi-unwrapped or (import ../. {
        inherit pkgs;
        llm-agents-pi = pkgs.pi; # fallback
      }).pi-unwrapped;
      description = "Pi package to install";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = ''
        Pi settings to write to ~/.config/pi/agent/settings.json.
        See https://github.com/badlogic/pi-mono/blob/main/docs/settings.md
      '';
      example = lib.literalExpression ''
        {
          defaultProvider = "anthropic";
          defaultModel = "claude-sonnet-4-20250514";
          theme = "dark";
          compaction = {
            enabled = true;
            reserveTokens = 16384;
          };
        }
      '';
    };

    agentsMd = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Global AGENTS.md content";
    };

    systemMd = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Global SYSTEM.md content";
    };

    appendSystemMd = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Global APPEND_SYSTEM.md content";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    # Write immutable global config files to XDG directory
    xdg.configFile."pi/agent/settings.json" = lib.mkIf (cfg.settings != {}) {
      source = pkgs.writeText "pi-settings.json" (builtins.toJSON cfg.settings);
    };

    xdg.configFile."pi/agent/AGENTS.md" = lib.mkIf (cfg.agentsMd != null) {
      text = cfg.agentsMd;
    };

    xdg.configFile."pi/agent/SYSTEM.md" = lib.mkIf (cfg.systemMd != null) {
      text = cfg.systemMd;
    };

    xdg.configFile."pi/agent/APPEND_SYSTEM.md" = lib.mkIf (cfg.appendSystemMd != null) {
      text = cfg.appendSystemMd;
    };

    # Export environment variables so Pi discovers the XDG config
    home.sessionVariables = {
      PI_CODING_AGENT_DIR = "${config.xdg.configHome}/pi/agent";
      PI_CODING_AGENT_SESSION_DIR = "${config.home.homeDirectory}/.pi/agent/sessions";
    };
  };
}