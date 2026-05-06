# Exportable flake module - configurable pi wrapper
{config, lib, ...}: {
  options = {
    devtools.pi = {
      enable = lib.mkEnableOption "Enable configurable Pi wrapper package";
      
      package = lib.mkOption {
        type = lib.types.package;
        description = "Base pi-unwrapped package to wrap";
      };

      model = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Override default model (--model)";
      };

      provider = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Override default provider (--provider)";
      };

      thinking = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Override default thinking level (--thinking)";
      };

      models = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Model patterns for Ctrl+P cycling (--models)";
      };

      extensions = lib.mkOption {
        type = lib.types.listOf lib.types.path;
        default = [];
        description = "Additional extensions to load (--extension)";
      };

      skills = lib.mkOption {
        type = lib.types.listOf lib.types.path;
        default = [];
        description = "Additional skills to load (--skill)";
      };

      themes = lib.mkOption {
        type = lib.types.listOf lib.types.path;
        default = [];
        description = "Additional themes to load (--theme)";
      };

      prompts = lib.mkOption {
        type = lib.types.listOf lib.types.path;
        default = [];
        description = "Additional prompt templates to load (--prompt-template)";
      };

      tools = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "Tool allowlist (--tools)";
      };

      noBuiltinTools = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Disable built-in tools (--no-builtin-tools)";
      };

      noTools = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Disable all tools (--no-tools)";
      };

      noExtensions = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Disable extension discovery (--no-extensions)";
      };

      noSkills = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Disable skill discovery (--no-skills)";
      };

      noThemes = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Disable theme discovery (--no-themes)";
      };

      noPrompts = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Disable prompt template discovery (--no-prompt-templates)";
      };

      noContextFiles = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Disable AGENTS.md discovery (--no-context-files)";
      };

      systemPrompt = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Replace default system prompt (--system-prompt)";
      };

      appendSystemPrompt = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Append to system prompt (--append-system-prompt)";
      };

      offline = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Offline mode (--offline)";
      };

      verbose = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Verbose startup (--verbose)";
      };


    };
  };

  config = {
    perSystem = {
      config,
      pkgs,
      inputs',
      ...
    }: let
      cfg = config.devtools.pi;
      
      # Filter out non-wrapper args for callPackage
      wrapperArgs = lib.filterAttrs (name: value: 
        !(name == "enable" || name == "package")
      ) cfg;
    in
      lib.mkIf cfg.enable {
        packages.pi = pkgs.callPackage ./default.nix ({
          pi-unwrapped = cfg.package;
        } // wrapperArgs);
      };
  };
}