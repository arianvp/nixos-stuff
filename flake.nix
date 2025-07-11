{
  description = "Arian's computers";
  inputs.unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.stable.url = "github:NixOS/nixpkgs/nixos-24.11";
  inputs.webauthn.url = "github:arianvp/webauthn-oidc";
  inputs.nixos-hardware.url = "github:NixOS/nixos-hardware";
  inputs.lanzaboote = {
    url = "github:nix-community/lanzaboote/v0.4.2";
    inputs.nixpkgs.follows = "unstable";
  };
  inputs.nixos-generators = {
    url = "github:nix-community/nixos-generators";
    inputs.nixpkgs.follows = "unstable";
  };

  inputs.cgroup-exporter = {
    url = "github:arianvp/cgroups-exporter";
    inputs.nixpkgs.follows = "unstable";
  };

  outputs =
    {
      self,
      cgroup-exporter,
      lanzaboote,
      webauthn,
      stable,
      unstable,
      nixos-hardware,
      nixos-generators,
      ...
    }:
    {

      nixosModules = {
        cachix = ./modules/cachix.nix;
        direnv = ./modules/direnv.nix;
        dnssd = ./modules/dnssd.nix;
        prometheus-rules = ./modules/prometheus-rules.nix;
        monitoring = ./modules/monitoring.nix;
        overlays =
          { pkgs, ... }:
          {
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

      nixosConfigurations = {
        framework = unstable.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            nixos-hardware.nixosModules.framework-11th-gen-intel
            self.nixosModules.direnv
            self.nixosModules.dnssd
            self.nixosModules.prometheus-rules
            self.nixosModules.monitoring
            self.nixosModules.overlays
            cgroup-exporter.nixosModules.default
            lanzaboote.nixosModules.lanzaboote
            ./configs/framework/configuration.nix
          ];
        };
        /*
          ryzen = unstable.lib.nixosSystem {
          system = "x86_64-linux";
          modules = with self.nixosModules; [
            cachix
            ./configs/ryzen
          ];
          };
        */
        utm = stable.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            { networking.hostName = "utm"; }
            ./configs/utm/configuration.nix
          ];
        };
        spire = stable.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            ./configs/spire/configuration.nix
          ];
        };
        altra = unstable.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [ ./configs/altra/configuration.nix ];
        };
        arianvp-me = unstable.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
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
