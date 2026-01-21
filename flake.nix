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
      localSystems = [
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      commonModules = [
        sops-nix.nixosModules.sops
        ./nix/modules/hardware-aws.nix
        ./nix/modules/synapse.nix
        ./nix/modules/matrix-puppeteer-line.nix
      ];

      mkDevShell =
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        pkgs.mkShell {
          buildInputs = with pkgs; [
            terraform
            awscli2
            colmena.packages.${system}.colmena
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

      # Dev shells for all supported systems
      devShells = builtins.listToAttrs (
        map (system: {
          name = system;
          value = {
            default = mkDevShell system;
          };
        }) localSystems
      );
    };
}
