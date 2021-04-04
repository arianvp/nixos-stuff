{
  description = "Arian's computers";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-20.09";

  outputs = { self, nixpkgs }: {

    nixosModules = {
      cachix = import ./modules/cachix.nix;
      direnv = import ./modules/direnv.nix;
    };

    deploy.targets.node = {
    };

    nixosConfigurations = {
      t490s = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with self.nixosModules; [
          cachix
          direnv
          ./configs/t490s
          {
            nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = map import [
              ./overlays/user-environment.nix
              ./overlays/wire.nix
              ./overlays/fonts.nix
	      ./overlays/neovim.nix
	      ./overlays/vscodium.nix
            ];
          }
        ];
      };
      arianvp-me = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = with self.nixosModules; [
          cachix
          ./configs/arianvp.me
        ];
      };
    };
  };
}
