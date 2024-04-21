{
  description = "Nithesh's Development Tools";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    nil.url = "github:oxalica/nil";
    nixvim = {
      url = "github:nix-community/nixvim/nixos-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux"];

      imports = [
        ./helix/module.nix
        ./neovim/module.nix
      ];

      perSystem = {
        system,
        pkgs,
        self',
        inputs',
        ...
      }: {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            self'.packages.helix
            inputs'.nil.packages.default
            self'.formatter
          ];
        };
        formatter = pkgs.alejandra;
      };
    };
}
