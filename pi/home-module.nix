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

    # Immutable HM baseline (activation script seeds/merges mutable settings.json from this)
    home.file.".pi/agent/settings.hm-base.json" = lib.mkIf (cfg.settings != {}) {
      source = pkgs.writeText "pi-settings-hm-base.json" (builtins.toJSON cfg.settings);
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

    # Seed/merge mutable settings.json from HM baseline using deterministic JSON 3-way merge.
    home.activation.managePiSettings = lib.mkIf (cfg.settings != {}) (
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