{
  description = "LINE-Beeper: Matrix Synapse + LINE bridge on AWS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    colmena.url = "github:zhaofengli/colmena";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      colmena,
      sops-nix,
      ...
    }:
    let
      targetSystem = "aarch64-linux";
      localSystem = "x86_64-linux";

      pkgs = import nixpkgs { system = localSystem; };

      commonModules = [
        sops-nix.nixosModules.sops
        ./nix/modules/hardware-aws.nix
        ./nix/modules/synapse.nix
        ./nix/modules/matrix-puppeteer-line.nix
      ];
    in
    {
      # Colmena hive - stateless deployment
      colmenaHive = colmena.lib.makeHive {
        meta = {
          nixpkgs = import nixpkgs { system = targetSystem; };
          specialArgs = { inherit self; };
        };

        defaults =
          { ... }:
          {
            imports = commonModules;
          };

        line-beeper =
          {
            name,
            nodes,
            pkgs,
            ...
          }:
          {
            deployment = {
              targetHost = builtins.readFile ./target-host.txt;
              targetUser = "root";
              buildOnTarget = true;
            };
          };
      };

      # Dev shell
      devShells.${localSystem}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          terraform
          awscli2
          colmena.packages.${localSystem}.colmena
          sops
          jq
        ];

        shellHook = ''
          echo "LINE-Beeper dev environment"
          echo "  make deploy  - Full deployment"
          echo "  make infra   - Infrastructure only"
          echo "  make nixos   - NixOS config only"
        '';
      };
    };
}
