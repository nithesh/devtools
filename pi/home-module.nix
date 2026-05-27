# Home Manager module for Pi
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.pi;
  piPackageSet = import ./pi-packages.nix { inherit pkgs lib; };
  preludePackage = pkgs.callPackage ./prelude/package.nix {
    features = cfg.prelude.features;
  };
  wrapperExtensions =
    (lib.optional cfg.prelude.enable preludePackage)
    ++ cfg.extensions;
  basePackage =
    if cfg.package != null then cfg.package
    else throw "programs.pi.package must be set to a pi-unwrapped package (for example inputs.devtools.packages.${pkgs.system}.pi-unwrapped).";
  installedPackage =
    if wrapperExtensions != [ ] then
      pkgs.callPackage ./default.nix {
        pi-unwrapped = basePackage;
        extensions = wrapperExtensions;
        runtimeBins = cfg.runtimeBins;
      }
    else
      basePackage;
  settingsPackages = (cfg.settings.packages or [ ]) ++ (map toString cfg.packages);
  effectiveSettings =
    cfg.settings
    // lib.optionalAttrs (settingsPackages != [ ]) {
      packages = settingsPackages;
    };
in {
  meta.maintainers = [];

  options.programs.pi = {
    enable = lib.mkEnableOption "Pi coding agent";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Base pi-unwrapped package to install or wrap.";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = ''
        Pi settings baseline to merge into ~/.pi/agent/settings.json.
        `programs.pi.packages` is appended to `settings.packages` automatically.
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

    packages = lib.mkOption {
      type = lib.types.listOf (lib.types.oneOf [ lib.types.package lib.types.path lib.types.str ]);
      default = [];
      description = "Pi package derivations/paths/sources to add to settings.packages.";
    };

    availablePackages = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = piPackageSet;
      description = "Namespaced Pi package set for Home Manager usage.";
    };

    extensions = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [];
      description = "Additional extension paths loaded by the installed Pi wrapper.";
    };

    runtimeBins = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Extra binaries to put on PATH for wrapper-loaded extensions.";
    };

    prelude = {
      enable = lib.mkEnableOption "pi prelude package for the Home Manager installed wrapper";
      features = {
        mode.enable = lib.mkOption { type = lib.types.bool; default = true; };
        status.enable = lib.mkOption { type = lib.types.bool; default = true; };
        guardrails.enable = lib.mkOption { type = lib.types.bool; default = true; };
        tools.ask.enable = lib.mkOption { type = lib.types.bool; default = true; };
        tools.todo.enable = lib.mkOption { type = lib.types.bool; default = true; };
        tools.web.enable = lib.mkOption { type = lib.types.bool; default = true; };
      };
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
    home.packages = [installedPackage];

    # Immutable HM baseline (activation script seeds/merges mutable settings.json from this)
    home.file.".pi/agent/settings.hm-base.json" = lib.mkIf (effectiveSettings != {}) {
      source = pkgs.writeText "pi-settings-hm-base.json" (builtins.toJSON effectiveSettings);
    };

    home.file.".pi/agent/AGENTS.md" = lib.mkIf (cfg.agentsMd != null) {
      text = cfg.agentsMd;
    };

    home.file.".pi/agent/SYSTEM.md" = lib.mkIf (cfg.systemMd != null) {
      text = cfg.systemMd;
    };

    home.file.".pi/agent/APPEND_SYSTEM.md" = lib.mkIf (cfg.appendSystemMd != null) {
      text = cfg.appendSystemMd;
    };

    # Seed/merge mutable settings.json from HM baseline using deterministic JSON 3-way merge.
    home.activation.managePiSettings = lib.mkIf (effectiveSettings != {}) (
      lib.hm.dag.entryAfter ["writeBoundary"] ''
        set -eu

        PI_DIR="$HOME/.pi/agent"
        BASE="$PI_DIR/settings.hm-base.json"
        PREV_BASE="$PI_DIR/settings.hm-last-applied-base.json"
        LOCAL="$PI_DIR/settings.json"
        REPORT="$PI_DIR/settings.merge-conflicts.json"
        JQ_BIN='${lib.getExe pkgs.jq}'

        mkdir -p "$PI_DIR"

        # First-time seed: create mutable settings.json + initialize last-applied baseline.
        if [[ -f "$BASE" ]] && [[ ! -f "$LOCAL" ]]; then
          cp "$BASE" "$LOCAL"
          cp "$BASE" "$PREV_BASE"
          echo "Seeded Pi settings: $LOCAL"
          exit 0
        fi

        # If no baseline or local config, nothing to do.
        if [[ ! -f "$BASE" ]] || [[ ! -f "$LOCAL" ]]; then
          exit 0
        fi

        # Initialize last-applied baseline if missing.
        if [[ ! -f "$PREV_BASE" ]]; then
          cp "$BASE" "$PREV_BASE"
        fi

        # No HM baseline change => nothing to merge.
        if cmp -s "$PREV_BASE" "$BASE"; then
          exit 0
        fi

        TMP_MERGED="$(mktemp)"
        TMP_CONFLICTS="$(mktemp)"

        "$JQ_BIN" -n \
          --slurpfile b "$PREV_BASE" \
          --slurpfile l "$LOCAL" \
          --slurpfile n "$BASE" '
            def m3($b; $l; $n):
              if ($l == $b and $n != $b) then $n
              elif ($l != $b and $n == $b) then $l
              elif ($l == $n) then $l
              elif (($b|type)=="object" and ($l|type)=="object" and ($n|type)=="object") then
                (([$b,$l,$n] | map(keys_unsorted) | add | unique) // []) as $ks
                | reduce $ks[] as $k ({}; .[$k] = m3($b[$k]; $l[$k]; $n[$k]))
              else
                {"__CONFLICT__": {"base": $b, "local": $l, "new": $n}}
              end;
            m3($b[0]; $l[0]; $n[0])
          ' > "$TMP_MERGED"

        "$JQ_BIN" '
          [paths(objects) as $p
           | (getpath($p)) as $v
           | select(($v|type)=="object" and ($v|has("__CONFLICT__")))
           | { path: ($p | map(tostring) | join(".")), conflict: $v.__CONFLICT__ }]
        ' "$TMP_MERGED" > "$TMP_CONFLICTS"

        if [[ "$($JQ_BIN 'length' "$TMP_CONFLICTS")" != "0" ]]; then
          cp "$TMP_CONFLICTS" "$REPORT"
          rm -f "$TMP_MERGED" "$TMP_CONFLICTS"
          echo "WARNING: Pi settings merge conflicts detected; keeping user settings unchanged."
          echo "         Conflicts: $REPORT"
          echo "         Baselines: $PREV_BASE -> $BASE"
          exit 0
        fi

        mv "$TMP_MERGED" "$LOCAL"
        rm -f "$TMP_CONFLICTS" "$REPORT"
        cp "$BASE" "$PREV_BASE"
        echo "Merged HM Pi settings updates into $LOCAL"
      ''
    );

    # Export environment variables
    home.sessionVariables = {
      # PI_CODING_AGENT_DIR not set - let Pi use default ~/.pi/agent/
      PI_CODING_AGENT_SESSION_DIR = "${config.home.homeDirectory}/.pi/agent/sessions";
    };
  };
}