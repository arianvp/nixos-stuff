{
  description = "Arian's computers";

  inputs = {
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "unstable";
    };
    cgroup-exporter = {
      url = "github:arianvp/cgroups-exporter";
      inputs.nixpkgs.follows = "unstable";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "unstable";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "unstable";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "unstable";
    };
  };

  outputs =
    {
      cgroup-exporter,
      home-manager,
      lanzaboote,
      nix-darwin,
      nixos-hardware,
      noctalia,
      unstable,
      ...
    }:
    let
      inherit (unstable.lib.modules) importApply;

      forSystems =
        systems: f: unstable.lib.genAttrs systems (system: f unstable.legacyPackages.${system});

      # Opt-in home-manager wiring, pre-applied so the hosts that want it need
      # only import it rather than name its inputs.
      homeManagerModule = importApply ./modules/nixos/home-manager.nix {
        inherit home-manager;
      };

      # Desktop shell; only hosts that have a screen want this.
      noctaliaModule = importApply ./modules/nixos/noctalia.nix { inherit noctalia; };

      # Every host gets ./modules/nixos resp. ./modules/darwin; anything else it
      # needs it imports itself from its own configuration.nix. Modules that need
      # a flake input are `importApply`d with exactly that input, so nothing has
      # to take specialArgs or an open `inputs` bag.
      nixosSystem =
        host:
        unstable.lib.nixosSystem {
          modules = [
            (importApply ./modules/nixos { inherit cgroup-exporter; })
            host
          ];
        };

      darwinSystem =
        host:
        nix-darwin.lib.darwinSystem {
          modules = [
            (importApply ./modules/darwin { inherit home-manager; })
            host
          ];
        };
    in
    {
      overlays.spire = import ./overlays/spire.nix;

      devShells = forSystems [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (import ./devshells.nix);
      packages = forSystems [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (import ./packages);
      checks = forSystems [ "x86_64-linux" "aarch64-linux" ] (import ./checks.nix);

      nixosConfigurations = {
        framework = nixosSystem (
          importApply ./hosts/framework/configuration.nix {
            inherit
              nixos-hardware
              lanzaboote
              homeManagerModule
              noctaliaModule
              ;
          }
        );
        utm = nixosSystem ./hosts/utm/configuration.nix;
        altra = nixosSystem (
          importApply ./hosts/altra/configuration.nix {
            inherit nixos-hardware homeManagerModule;
          }
        );
        arianvp-me = nixosSystem ./hosts/arianvp.me/configuration.nix;
        minecraft = nixosSystem ./hosts/minecraft/configuration.nix;
      };

      darwinConfigurations = {
        "Arians-MacBook-Pro" = darwinSystem ./hosts/Arians-MacBook-Pro/configuration.nix;
        "Arians-Mac-mini" = darwinSystem ./hosts/Arians-Mac-mini/configuration.nix;
      };
    };
}
