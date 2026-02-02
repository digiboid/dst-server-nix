{
  description = "NixOS module for Don't Starve Together dedicated server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # NixOS module output (system-independent)
      moduleOutputs = {
        nixosModules.default = import ./modules/dst-server.nix;
        nixosModules.dst-server = self.nixosModules.default;
      };

      # Per-system outputs (packages, devShells, etc.)
      perSystemOutputs = flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true; # steamcmd requires unfree
          };
        in
        {
          packages = {
            dst-server-scripts = pkgs.callPackage ./packages/dst-server-scripts.nix { };
            default = self.packages.${system}.dst-server-scripts;
          };

          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs; [
              steamcmd
              nixpkgs-fmt
              nil # Nix LSP
            ];

            shellHook = ''
              echo "Don't Starve Together Server Development Environment"
              echo ""
              echo "Available commands:"
              echo "  steamcmd      - Steam command line client"
              echo "  nixpkgs-fmt   - Format Nix files"
              echo ""
              echo "To test the module:"
              echo "  nix flake check"
              echo "  nix flake show"
            '';
          };

          # App to generate cluster token instructions
          apps.generate-token = {
            type = "app";
            program = "${self.packages.${system}.dst-server-scripts}/bin/dst-generate-token";
          };
        });
    in
    moduleOutputs // perSystemOutputs;
}
