# Unified pi module: base package + configurable wrapper options
{ config, lib, flake-parts-lib, ... }:
let
  rootCfg = config.devtools.pi;
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption ({ ... }: {
    options.devtools.pi.packageExtensions = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Pi package derivations to include in generated project .pi/settings.json.";
    };
  });
  options = {
    devtools.pi = {
      enable = lib.mkEnableOption "Enable configurable Pi wrapper package";

      package = lib.mkOption {
        type = lib.types.package;
        description = "Base pi-unwrapped package to wrap";
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
        pi-unwrapped = inputs'.llm-agents.packages.pi;
        cfg = rootCfg // {
          package = if rootCfg.package or null != null then rootCfg.package else pi-unwrapped;
          managedSettings = (rootCfg.managedSettings or { }) // {
            enable = (rootCfg.managedSettings.enable or false);
            packages = (rootCfg.managedSettings.packages or [ ]);
            extra = (rootCfg.managedSettings.extra or { });
          };
        };
        wrapperArgs = lib.filterAttrs (name: _value: !(builtins.elem name [ "enable" "package" "managedSettings" ])) cfg;

        managedPackageSources = config.devtools.pi.packageExtensions ++ cfg.managedSettings.packages;

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
        packages.pi-unwrapped = pi-unwrapped;
        packages.pi = if cfg.enable then pkgs.callPackage ./default.nix ({ pi-unwrapped = cfg.package; } // wrapperArgs) else pi-unwrapped;
        packages.pi-manage-settings = manageSettingsScript;
      };
  };
}
