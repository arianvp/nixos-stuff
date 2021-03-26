{
  description = "Arian's computers";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

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
      arianvp-me = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./configs/arianvp.me ];
      };
    };
  };
}
