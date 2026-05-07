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
        ./pi/module.nix  # registers packages.pi-unwrapped and packages.pi (unwrapped)
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
        let
          # Create a customized pi for our devShell
          dev-pi = pkgs.callPackage ./pi/default.nix {
            pi-unwrapped = config.packages.pi-unwrapped;
            # Add your preferred devShell Pi configuration here:
            # model = "anthropic/claude-sonnet-4-20250514";
            # provider = "anthropic";
            # piThemes = [ ./path/to/theme.json ];
            # extensions = [ ./path/to/dev-extension.ts ];
          };
        in
        {
          devShells.default = pkgs.mkShell {
            buildInputs = [
              self'.packages.helix
              self'.packages.zed
              dev-pi  # use our custom wrapped pi in devShell
              inputs'.nil.packages.default
              self'.formatter
            ];
          };
          formatter = pkgs.alejandra;
        };

      flake = {
        homeManagerModules.pi = import ./pi/home-module.nix;
        flakeModules.pi = import ./pi/flake-module.nix;
      };
    };
}
