{ config, lib, ... }:
let
  cfg = config.devtools.pi.prelude;
in
{
  options.devtools.pi.prelude = {
    enable = lib.mkEnableOption "pi-prelude wrapped Pi package";

    checks.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable pi-prelude check derivations.";
    };

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Base pi package to wrap (defaults to pi-unwrapped)";
    };

    extraExtensionSources = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Additional extension/package sources passed via --extension";
    };

    extraArgs = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra args passed to pi/default.nix wrapper";
    };
  };

  config = {
    perSystem = { config, pkgs, ... }:
      lib.mkIf cfg.enable (
        let
          preludePackage = pkgs.runCommand "pi-prelude-package" { } ''
            mkdir -p "$out"
            cp -R ${./.}/. "$out/"
          '';
        in
        {
          packages.pi-prelude-package = preludePackage;

          packages.pi-prelude = pkgs.callPackage ../default.nix (
            {
              pi-unwrapped = if cfg.package != null then cfg.package else config.packages.pi-unwrapped;
              extensions = [ preludePackage ] ++ cfg.extraExtensionSources;
              runtimeBins = [ pkgs.ddgr pkgs.curl ];
            }
            // cfg.extraArgs
          );
        }
        // lib.optionalAttrs cfg.checks.enable {
          checks.pi-prelude-build = config.packages.pi-prelude;

          checks.pi-prelude-contract = pkgs.runCommand "pi-prelude-contract-test" {
            nativeBuildInputs = [ pkgs.bun ];
            PI_PRELUDE_BIN = "${config.packages.pi-prelude}/bin/pi";
            PI_PRELUDE_PACKAGE_DIR = "${config.packages.pi-prelude-package}";
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

          checks.pi-prelude-status-isolation = pkgs.runCommand "pi-prelude-status-isolation-test" {
            nativeBuildInputs = [ pkgs.bun ];
            TEST_SCRIPT = "${./tests/status-isolation.test.ts}";
            STATUS_SOURCE_PATH = "${./extensions/status.ts}";
          } ''
            bun "$TEST_SCRIPT"
            touch "$out"
          '';

          checks.pi-prelude-ask-isolation = pkgs.runCommand "pi-prelude-ask-isolation-test" {
            nativeBuildInputs = [ pkgs.bun ];
            TEST_SCRIPT = "${./tests/ask-isolation.test.ts}";
            ASK_SOURCE_PATH = "${./extensions/tools-ask.ts}";
          } ''
            bun "$TEST_SCRIPT"
            touch "$out"
          '';

          checks.pi-prelude-guardrails-isolation = pkgs.runCommand "pi-prelude-guardrails-isolation-test" {
            nativeBuildInputs = [ pkgs.bun ];
            TEST_SCRIPT = "${./tests/guardrails-isolation.test.ts}";
            GUARDRAILS_SOURCE_PATH = "${./extensions/guardrails.ts}";
          } ''
            bun "$TEST_SCRIPT"
            touch "$out"
          '';
        }
      );
  };
}
