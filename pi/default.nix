# mkPiWrapper - Build a Pi wrapper with CLI args
{
  pkgs
, pi-unwrapped
, model ? null
, provider ? null
, thinking ? null
, models ? []
, extensions ? []
, skills ? []
, piThemes ? []
, prompts ? []
, tools ? null
, noBuiltinTools ? false
, noTools ? false
, noExtensions ? false
, noSkills ? false
, noThemes ? false
, noPrompts ? false
, noContextFiles ? false
, systemPrompt ? null
, appendSystemPrompt ? null
, offline ? false
, verbose ? false
, blockMutating ? true
}:

let
  inherit (pkgs.lib) 
    optional optionals concatLists concatStringsSep escapeShellArg
    boolToString;

  # Helper to build flag lists
  flag = opt: val: optional (val != null) [ "--${opt}" val ];
  listFlag = opt: vals: concatLists (map (v: [ "--${opt}" v ]) vals);
  commaFlag = opt: vals: optional (vals != []) [ "--${opt}" (concatStringsSep "," vals) ];
  boolFlag = opt: val: optional val [ "--${opt}" ];

  # Build all CLI args
  cliArgs = 
    flag "model" model ++
    flag "provider" provider ++
    flag "thinking" thinking ++
    commaFlag "models" models ++
    listFlag "extension" extensions ++
    listFlag "skill" skills ++
    listFlag "theme" piThemes ++
    listFlag "prompt-template" prompts ++
    (optional (tools != null) [ "--tools" (concatStringsSep "," tools) ]) ++
    boolFlag "no-builtin-tools" noBuiltinTools ++
    boolFlag "no-tools" noTools ++
    boolFlag "no-extensions" noExtensions ++
    boolFlag "no-skills" noSkills ++
    boolFlag "no-themes" noThemes ++
    boolFlag "no-prompt-templates" noPrompts ++
    boolFlag "no-context-files" noContextFiles ++
    flag "system-prompt" systemPrompt ++
    flag "append-system-prompt" appendSystemPrompt ++
    boolFlag "offline" offline ++
    boolFlag "verbose" verbose;

  # Format and escape all args for shell
  escapedArgs = concatStringsSep " " (map escapeShellArg (concatLists cliArgs));

in
pkgs.writeShellScriptBin "pi" ''
  # Set agent directory to XDG config path unless already set
  export PI_CODING_AGENT_DIR="''${PI_CODING_AGENT_DIR:-$HOME/.config/pi/agent}"
  
  # Preserve sessions in legacy location unless overridden
  export PI_CODING_AGENT_SESSION_DIR="''${PI_CODING_AGENT_SESSION_DIR:-$HOME/.pi/agent/sessions}"

  # Block mutating commands in wrapped mode
  ${
    if blockMutating then ''
  case "$1" in
    install|remove|uninstall|update|config)
      echo "error: '$1' is disabled in the wrapped Pi." >&2
      echo "       Manage resources declaratively in your flake or Home Manager." >&2
      exit 1
      ;;
  esac
    '' else ""
  }

  # Execute wrapped pi with CLI args
  exec ${pi-unwrapped}/bin/pi ${escapedArgs} "$@"
''