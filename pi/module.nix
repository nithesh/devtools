# Unified pi module: base package + configurable wrapper options
{ config, lib, flake-parts-lib, inputs, ... }:
let
  rootCfg = config.devtools.pi;
in
{
  imports = [
    ./prelude/module.nix
  ];
  options.perSystem = flake-parts-lib.mkPerSystemOption ({ ... }: {
    options.devtools.pi.basePackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Base pi-unwrapped package to wrap for this system.";
    };

    options.devtools.pi.piPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Pi package derivations to include in generated project .pi/settings.json.";
    };

    options.devtools.pi.availablePackages = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      description = "Namespaced Pi package set (similar to pythonPackages/vimPlugins).";
    };
  });
  options = {
    devtools.pi = {
      enable = lib.mkEnableOption "Enable configurable Pi wrapper package";

      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "Deprecated root-level base package override. Prefer perSystem.devtools.pi.basePackage.";
      };

      model = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "Override default model (--model)"; };
      provider = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "Override default provider (--provider)"; };
      thinking = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "Override default thinking level (--thinking)"; };
      models = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; description = "Model patterns for Ctrl+P cycling (--models)"; };
      extensions = lib.mkOption { type = lib.types.listOf lib.types.path; default = [ ]; description = "Additional extensions to load (--extension)"; };
      skills = lib.mkOption { type = lib.types.listOf lib.types.path; default = [ ]; description = "Additional skills to load (--skill)"; };
      themes = lib.mkOption { type = lib.types.listOf lib.types.path; default = [ ]; description = "Additional themes to load (--theme)"; };
      prompts = lib.mkOption { type = lib.types.listOf lib.types.path; default = [ ]; description = "Additional prompt templates to load (--prompt-template)"; };
      tools = lib.mkOption { type = lib.types.nullOr (lib.types.listOf lib.types.str); default = null; description = "Tool allowlist (--tools)"; };
      noBuiltinTools = lib.mkOption { type = lib.types.bool; default = false; description = "Disable built-in tools (--no-builtin-tools)"; };
      noTools = lib.mkOption { type = lib.types.bool; default = false; description = "Disable all tools (--no-tools)"; };
      noExtensions = lib.mkOption { type = lib.types.bool; default = false; description = "Disable extension discovery (--no-extensions)"; };
      noSkills = lib.mkOption { type = lib.types.bool; default = false; description = "Disable skill discovery (--no-skills)"; };
      noThemes = lib.mkOption { type = lib.types.bool; default = false; description = "Disable theme discovery (--no-themes)"; };
      noPrompts = lib.mkOption { type = lib.types.bool; default = false; description = "Disable prompt template discovery (--no-prompt-templates)"; };
      noContextFiles = lib.mkOption { type = lib.types.bool; default = false; description = "Disable AGENTS.md discovery (--no-context-files)"; };
      systemPrompt = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "Replace default system prompt (--system-prompt)"; };
      appendSystemPrompt = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "Append to system prompt (--append-system-prompt)"; };
      offline = lib.mkOption { type = lib.types.bool; default = false; description = "Offline mode (--offline)"; };
      verbose = lib.mkOption { type = lib.types.bool; default = false; description = "Verbose startup (--verbose)"; };

      managedSettings = {
        enable = lib.mkEnableOption "Manage .pi/settings.json from Nix on shell entry";
        packages = lib.mkOption {
          type = lib.types.listOf (lib.types.oneOf [ lib.types.path lib.types.str ]);
          default = [ ];
          description = "Additional non-derivation Pi package sources for project-local .pi/settings.json (paths or npm:/git: sources).";
        };
        extra = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Extra JSON fields merged into generated .pi/settings.json.";
        };
      };

    };
  };

  config = {
    perSystem = { config, pkgs, inputs', ... }:
      let
        piPackageSet = import ./pi-packages.nix { inherit pkgs lib; };

        defaultFromDevtoolsInput =
          if inputs ? devtools then inputs.devtools.packages.${pkgs.system}.pi-unwrapped else null;

        resolvedBasePackage =
          if config.devtools.pi.basePackage != null then config.devtools.pi.basePackage
          else if rootCfg.package != null then rootCfg.package
          else if defaultFromDevtoolsInput != null then defaultFromDevtoolsInput
          else if inputs' ? llm-agents then inputs'.llm-agents.packages.pi
          else throw "devtools.flakeModules.pi: unable to resolve base Pi package. Set perSystem.devtools.pi.basePackage (recommended).";

        preludeExtensions =
          lib.optional rootCfg.prelude.enable config.packages.pi-prelude-package;

        cfg = rootCfg // {
          package = resolvedBasePackage;
          extensions = preludeExtensions ++ rootCfg.extensions;
          managedSettings = (rootCfg.managedSettings or { }) // {
            enable = (rootCfg.managedSettings.enable or false);
            packages = (rootCfg.managedSettings.packages or [ ]);
            extra = (rootCfg.managedSettings.extra or { });
          };
        };

        wrapperArgs = {
          inherit (cfg)
            model provider thinking models extensions skills prompts tools
            noBuiltinTools noTools noExtensions noSkills noThemes noPrompts
            noContextFiles systemPrompt appendSystemPrompt offline verbose;
          piThemes = cfg.themes;
        };

        managedPackageSources = config.devtools.pi.piPackages ++ cfg.managedSettings.packages;

        managedSettingsJson = builtins.toJSON (cfg.managedSettings.extra // {
          packages = map toString managedPackageSources;
        });

        manageSettingsScript = pkgs.writeShellScriptBin "pi-manage-settings" ''
          mkdir -p .pi
          _pi_settings_tmp="$(mktemp)"
          cat > "$_pi_settings_tmp" <<'EOF'
          ${managedSettingsJson}
          EOF
          if [ ! -f .pi/settings.json ] || ! cmp -s "$_pi_settings_tmp" .pi/settings.json; then
            mv "$_pi_settings_tmp" .pi/settings.json
          else
            rm -f "$_pi_settings_tmp"
          fi
        '';
      in
      {
        devtools.pi.availablePackages = piPackageSet;

        packages = {
          pi-unwrapped = resolvedBasePackage;
          pi = if cfg.enable then pkgs.callPackage ./default.nix ({ pi-unwrapped = resolvedBasePackage; } // wrapperArgs) else resolvedBasePackage;
          pi-manage-settings = manageSettingsScript;
        };
      };
  };
}
