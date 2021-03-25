{
  description = "Arian's computers";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-20.09";

  outputs = { self, nixpkgs }: {

    nixosConfigurations = {
      t490s = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configs/t490s
          {
            nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = map import [
              ./overlays/user-environment.nix
              ./overlays/wire.nix
              ./overlays/fonts.nix
            ];
          }
        ];
      };
    };
  };
}
