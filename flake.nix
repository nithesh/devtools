{
  description = "Nithesh's Development Tools";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nil.url = "github:oxalica/nil";
    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [
        ./helix/module.nix
        ./neovim/module.nix
        ./zed/module.nix
        ./zellij/module.nix
        ./pi/module.nix
        ./pi/prelude/module.nix
        ./agent-console/module.nix
      ];

      devtools.pi.prelude.enable = true;

      perSystem =
        {
          system,
          pkgs,
          self',
          inputs',
          config,
          ...
        }:
        let
          dev-pi = pkgs.writeShellScriptBin "pi" ''
            set -euo pipefail

            ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
            PRELUDE_PATH="$ROOT/pi/prelude"

            exec ${self'.packages.pi-unwrapped}/bin/pi --extension "$PRELUDE_PATH" "$@"
          '';
        in
        {
          devShells.default = pkgs.mkShell {
            buildInputs = [
              self'.packages.helix
              self'.packages.zed
              self'.packages.neovim
              self'.packages.zellij
              self'.packages.agent-console
              dev-pi
              inputs'.nil.packages.default
              self'.formatter
            ];
          };

          checks = {
            agent-console-behavior = pkgs.runCommand "agent-console-behavior-test" {
              nativeBuildInputs = [ pkgs.bash pkgs.gnugrep pkgs.coreutils ];
              AGENT_CONSOLE_BIN = "${self'.packages.agent-console}/bin/agent-console";
            } ''
              ${pkgs.bash}/bin/bash ${./tests/agent-console-behavior.sh}
              touch "$out"
            '';

            agent-console-extension = pkgs.runCommand "agent-console-extension-test" {
              nativeBuildInputs = [ pkgs.bash pkgs.gnugrep pkgs.coreutils ];
              EXT_PATH = "${./agent-console/extensions/nvim-rpc.ts}";
            } ''
              ${pkgs.bash}/bin/bash ${./tests/agent-console-extension-test.sh}
              touch "$out"
            '';
          };

          formatter = pkgs.alejandra;
        };

      flake = {
        homeManagerModules.pi = import ./pi/home-module.nix;
        flakeModules.pi = import ./pi/flake-module.nix;
        flakeModules.pi-prelude = import ./pi/prelude/module.nix;
        flakeModules.agent-console = import ./agent-console/flake-module.nix;
      };
    };
}
