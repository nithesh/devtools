{ config, lib, ... }:
let
  cfg = config.devtools.pi.prelude;
in
{
  options.devtools.pi.prelude = {
    enable = lib.mkEnableOption "pi prelude extensions" // { default = true; };

    checks.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable pi-prelude check derivations.";
    };

    features = {
      mode.enable = lib.mkOption { type = lib.types.bool; default = true; };
      status.enable = lib.mkOption { type = lib.types.bool; default = true; };
      guardrails.enable = lib.mkOption { type = lib.types.bool; default = true; };
      tools.ask.enable = lib.mkOption { type = lib.types.bool; default = true; };
      tools.todo.enable = lib.mkOption { type = lib.types.bool; default = true; };
      tools.web.enable = lib.mkOption { type = lib.types.bool; default = true; };
    };
  };

  config = {
    perSystem = { config, pkgs, ... }:
      let
        preludePackage = pkgs.callPackage ./package.nix {
          features = cfg.features;
        };

        preludeArgs = lib.optionalString cfg.enable "--extension ${preludePackage}";

        piDev = pkgs.writeShellScriptBin "pi" ''
          set -euo pipefail
          exec ${config.packages.pi-unwrapped}/bin/pi ${preludeArgs} "$@"
        '';

        piWithPreludeForChecks = pkgs.callPackage ../default.nix {
          pi-unwrapped = config.packages.pi-unwrapped;
          extensions = [ preludePackage ];
          runtimeBins = [ pkgs.ddgr pkgs.curl ];
        };
      in
      {
        packages.pi-dev = piDev;
        packages.pi-prelude-package = preludePackage;
      }
      // lib.optionalAttrs (cfg.enable && cfg.checks.enable) ({
        checks.pi-prelude-build = piWithPreludeForChecks;

        checks.pi-prelude-contract = pkgs.runCommand "pi-prelude-contract-test" {
          nativeBuildInputs = [ pkgs.bun ];
          PI_PRELUDE_BIN = "${piWithPreludeForChecks}/bin/pi";
          PI_PRELUDE_PACKAGE_DIR = "${preludePackage}";
          PI_PRELUDE_FEATURES_JSON = builtins.toJSON {
            mode = cfg.features.mode.enable;
            status = cfg.features.status.enable;
            guardrails = cfg.features.guardrails.enable;
            toolsAsk = cfg.features.tools.ask.enable;
            toolsTodo = cfg.features.tools.todo.enable;
            toolsWeb = cfg.features.tools.web.enable;
          };
          TEST_SCRIPT = "${./tests/contract.ts}";
        } ''
          bun "$TEST_SCRIPT"
          touch "$out"
        '';

        checks.pi-prelude-guardrails = pkgs.runCommand "pi-prelude-guardrails-test" {
          nativeBuildInputs = [ pkgs.bun ];
          TEST_SCRIPT = "${./tests/guardrails.test.ts}";
        } ''
          bun "$TEST_SCRIPT"
          touch "$out"
        '';
      }
      // lib.optionalAttrs cfg.features.status.enable {
        checks.pi-prelude-status-isolation = pkgs.runCommand "pi-prelude-status-isolation-test" {
          nativeBuildInputs = [ pkgs.bun ];
          TEST_SCRIPT = "${./tests/status-isolation.test.ts}";
          STATUS_SOURCE_PATH = "${./extensions/status.ts}";
        } ''
          bun "$TEST_SCRIPT"
          touch "$out"
        '';
      }
      // lib.optionalAttrs cfg.features.tools.ask.enable {
        checks.pi-prelude-ask-isolation = pkgs.runCommand "pi-prelude-ask-isolation-test" {
          nativeBuildInputs = [ pkgs.bun ];
          TEST_SCRIPT = "${./tests/ask-isolation.test.ts}";
          ASK_SOURCE_PATH = "${./extensions/tools-ask.ts}";
        } ''
          bun "$TEST_SCRIPT"
          touch "$out"
        '';
      }
      // lib.optionalAttrs cfg.features.guardrails.enable {
        checks.pi-prelude-guardrails-isolation = pkgs.runCommand "pi-prelude-guardrails-isolation-test" {
          nativeBuildInputs = [ pkgs.bun ];
          TEST_SCRIPT = "${./tests/guardrails-isolation.test.ts}";
          GUARDRAILS_SOURCE_PATH = "${./extensions/guardrails.ts}";
        } ''
          bun "$TEST_SCRIPT"
          touch "$out"
        '';
      });
  };
}
