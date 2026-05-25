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
        ./agent-console/module.nix
      ];

      perSystem =
        {
          system,
          pkgs,
          self',
          inputs',
          config,
          ...
        }:
        {
          devtools.pi = {
            piPackages = with config.devtools.pi.availablePackages; [
              rpiv."web-tools"
              rpiv.todo
              rpiv."ask-user-question"
              whatsappPi
            ];
          };

          devShells.default = pkgs.mkShell {
            buildInputs = [
              self'.packages.helix
              self'.packages.zed
              self'.packages.neovim
              self'.packages.zellij
              self'.packages.agent-console
              self'.packages.pi-dev
              inputs'.nil.packages.default
              self'.formatter
            ];
            shellHook = ''
              ${self'.packages.pi-manage-settings}/bin/pi-manage-settings
            '';
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

      devtools.pi = {
        managedSettings.enable = true;
        prelude.features.tools = {
          web.enable = false;
          todo.enable = false;
          ask.enable = false;
        };
      };

      flake = {
        homeManagerModules.pi = import ./pi/home-module.nix;
        flakeModules.neovim = import ./neovim/module.nix;
        flakeModules.pi = import ./pi/module.nix;
        flakeModules.pi-prelude = import ./pi/prelude/module.nix;
        flakeModules.agent-console = import ./agent-console/flake-module.nix;
      };
    };
}
