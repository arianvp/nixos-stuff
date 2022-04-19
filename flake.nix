{
  description = "Arian's computers";

  inputs.helsinki.url = "github:helsinki-systems/nixpkgs/feat/systemd-stage-1-luks";
  inputs.unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.stable.url = "github:NixOS/nixpkgs/nixos-21.05";
  inputs.webauthn.url = "github:arianvp/webauthn-oidc";
  inputs.nixos-hardware.url = "github:NixOS/nixos-hardware";
  inputs.nixos-generators = {
    url = "github:nix-community/nixos-generators";
    inputs.nixpkgs.follows = "unstable";
  };

  outputs = { self, webauthn, stable, unstable, nixos-hardware, nixos-generators , helsinki }: {

    nixosModules = {
      cachix = import ./modules/cachix.nix;
      direnv = import ./modules/direnv.nix;
      systemd-initrd = import ./modules/systemd-initrd.nix;
      device-mapper = import ./modules/device-mapper.nix;
      nixFlakes = { pkgs, ... }: {
        nix.package = pkgs.nix;
        nix.extraOptions = ''
          experimental-features = nix-command flakes
        '';
        nix.registry.nixpkgs.flake = unstable;
        nix.nixPath = [ "nixpkgs=${unstable}" ];
      };
      overlays = { pkgs, ... }: {
        nixpkgs.config.allowUnfree = true;
        environment.systemPackages = [ pkgs.user-environment ];
        nixpkgs.overlays = map import [
          ./overlays/user-environment.nix
          ./overlays/wire.nix
          ./overlays/fonts.nix
          ./overlays/neovim.nix
          ./overlays/vscodium.nix
          ./overlays/pkgs.nix
          # ./overlays/systemd-initrd.nix
        ];
      };
    };

    cachixDeploys = stable.legacyPackages.x86_64-linux.writeText "cachix-deploy.json" (builtins.toJSON {
      agents = {
        arianvp-me = self.nixosConfigurations.arianvp-me.config.system.build.toplevel;
        t430s = self.nixosConfigurations.t430s.config.system.build.toplevel;
      };
    });

    packages.x86_64-linux.frameworkISO = nixos-generators.nixosGenerate {
      pkgs = unstable.legacyPackages.x86_64-linux;
      modules = [ nixos-hardware.nixosModules.framework ];
      format = "iso";
    };

    nixosConfigurations =
      {
        t430s = unstable.lib.nixosSystem {
          system = "x86_64-linux";
          modules = with self.nixosModules; [
            cachix
            direnv
            overlays
            nixFlakes
            ./configs/t430s
          ];
        };
        framework = helsinki.lib.nixosSystem {
          system = "x86_64-linux";
          modules = with self.nixosModules; [
            nixos-hardware.nixosModules.framework
            nixFlakes
            direnv
            overlays
            ./configs/framework/configuration.nix
          ];
        };
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
