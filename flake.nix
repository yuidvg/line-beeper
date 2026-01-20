{
  description = "LINE-Beeper: Matrix Synapse + LINE bridge on AWS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, sops-nix }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      # NixOS configuration for the server
      nixosConfigurations.line-beeper = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          sops-nix.nixosModules.sops
          ./nix/modules/hardware-aws.nix
          ./nix/modules/synapse.nix
          ./nix/modules/matrix-puppeteer-line.nix
        ];
        specialArgs = { inherit self; };
      };

      # Packages
      packages.${system} = {
        matrix-puppeteer-line = pkgs.callPackage ./nix/packages/matrix-puppeteer-line.nix { };
        matrix-puppeteer-line-chrome = pkgs.callPackage ./nix/packages/matrix-puppeteer-line-chrome.nix { };
      };

      # Dev shell for local development
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          terraform
          awscli2
          sops
          age
        ];

        shellHook = ''
          echo "LINE-Beeper development environment"
          echo "Commands:"
          echo "  terraform -chdir=terraform init/plan/apply"
          echo "  sops secrets/secrets.yaml"
        '';
      };
    };
}
