{
  description = "Arian's computers";

  inputs.unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.stable.url = "github:NixOS/nixpkgs/nixos-20.09";

  outputs = { self, stable, unstable }: {

    nixosModules = {
      cachix = import ./modules/cachix.nix;
      direnv = import ./modules/direnv.nix;
    };

    deploy.targets.node = { };

    nixosConfigurations =
      let
        config = {
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
                ./overlays/systemd-initrd.nix
              ];
            }
          ];
        }; in
      {
        t490s = unstable.lib.nixosSystem config;
        t490s-stable = stable.lib.nixosSystem config;
        arianvp-me = unstable.lib.nixosSystem {
          system = "x86_64-linux";
          modules = with self.nixosModules; [
            cachix
            ./configs/arianvp.me
          ];
        };
      };
  };
}
