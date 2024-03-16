{
  description = "Arian's computers";

  # inputs.helsinki.url = "github:helsinki-systems/nixpkgs/feat/systemd-stage-1-luks";
  inputs.unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.stable.url = "github:NixOS/nixpkgs/nixos-21.05";
  inputs.webauthn.url = "github:arianvp/webauthn-oidc";
  inputs.nixos-hardware.url = "github:NixOS/nixos-hardware";
  inputs.lanzaboote = {
    url = "github:nix-community/lanzaboote/v0.3.0";
    inputs.nixpkgs.follows = "unstable";
  };
  inputs.nixos-generators = {
    url = "github:nix-community/nixos-generators";
    inputs.nixpkgs.follows = "unstable";
  };
  inputs.vscode-server.url = "github:nix-community/nixos-vscode-server";

  outputs = { self, webauthn, vscode-server, stable, unstable, nixos-hardware, nixos-generators, lanzaboote }: {

    nixosModules = {
      cachix = import ./modules/cachix.nix;
      direnv = import ./modules/direnv.nix;
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

    packages.x86_64-linux.frameworkISO = nixos-generators.nixosGenerate {
      pkgs = unstable.legacyPackages.x86_64-linux;
      modules = [ nixos-hardware.nixosModules.framework ];
      format = "iso";
    };

    packages.x86_64-linux.digitalOceanImage = nixos-generators.nixosGenerate {
      pkgs = unstable.legacyPackages.x86_64-linux;
      modules = [ ./configs/arianvp.me ];
      format = "do";
    };

    nixosConfigurations =
      {
        framework = unstable.lib.nixosSystem {
          system = "x86_64-linux";
          modules = with self.nixosModules; [
            nixos-hardware.nixosModules.framework-11th-gen-intel
            nixFlakes
            direnv
            overlays
            lanzaboote.nixosModules.lanzaboote
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
        utm = unstable.lib.nixosSystem {
          system = "aarch64-linux";
          modules = with self.nixosModules; [
            { networking.hostName = "utm"; }
            nixFlakes
            ./configs/utm/configuration.nix
            vscode-server.nixosModule
            ({ config, pkgs, ... }: {
              services.vscode-server.enable = true;
            })
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
