{
  description = "Arian's computers";

  inputs.fork.url = "/home/arian/Projects/nixos/nixpkgs";
  inputs.andir.url = "github:andir/nixpkgs/systemdv249";
  inputs.unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.stable.url = "github:NixOS/nixpkgs/nixos-21.05";
  inputs.webauthn.url = "github:arianvp/webauthn-oidc";

  outputs = { self, webauthn, andir, stable, unstable, fork }: {

    nixosModules = {
      cachix = import ./modules/cachix.nix;
      direnv = import ./modules/direnv.nix;
      systemd-initrd = import ./modules/systemd-initrd.nix;
      device-mapper = import ./modules/device-mapper.nix;
      overlays = {
              nixpkgs.config.allowUnfree = true;
              nixpkgs.overlays = map import [
                ./overlays/user-environment.nix
                ./overlays/wire.nix
                ./overlays/fonts.nix
                ./overlays/neovim.nix
                ./overlays/vscodium.nix
                # ./overlays/systemd-initrd.nix
              ];
            };
    };

    deploy.targets.node = { };

    nixosConfigurations =
      let
        configNew = {
          system = "x86_64-linux";
          modules = with self.nixosModules; [
            cachix
            direnv
            overlays
            # systemd-initrd
            # device-mapper
            ./configs/t490s
          ];
        };
        configOld = {
          system = "x86_64-linux";
          modules = with self.nixosModules; [
            cachix
            direnv
            overlays
            ./configs/t490s
          ];
        };
      in
      {
        t490s = unstable.lib.nixosSystem configNew;
        t490s-fork = fork.lib.nixosSystem configNew;
        t490s-unstable = unstable.lib.nixosSystem configNew;
        ryzen = unstable.lib.nixosSystem {
          system = "x86_64-linux";
          modules = with self.nixosModules; [
            cachix
            ./configs/ryzen
          ];
        };
        arianvp-me = unstable.lib.nixosSystem {
          system = "x86_64-linux";
          modules = with self.nixosModules; [
            webauthn.nixosModule
            {

              services.webauthn-oidc.host = "oidc.arianvp.me";
              services.webauthn-oidc.createNginxConfig = true;
            }
            ./configs/arianvp.me
          ];
        };
      };
  };
}
