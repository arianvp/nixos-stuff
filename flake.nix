{
  description = "Arian's computers";
  inputs.unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.stable.url = "github:NixOS/nixpkgs/nixos-25.05";
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
      stable,
      unstable,
      nixos-hardware,
      nixos-generators,
      ...
    }:
    {

      devShells = unstable.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (
        system: with unstable.legacyPackages.${system}; {
          default = mkShell {
            packages = [
              doctl
              opentofu
            ];
          };
        }
      );

      nixosModules = {
        base = ./modules/base.nix;
        cachix = ./modules/cachix.nix;
        direnv = ./modules/direnv.nix;
        diff = ./modules/diff.nix;
        dnssd = ./modules/dnssd.nix;
        monitoring = ./modules/monitoring.nix;
        prometheus = ./modules/prometheus.nix;
        alertmanager = ./modules/alertmanager.nix;
        grafana = ./modules/grafana.nix;
        inputs = {
          _module.args.inputs.self = self;
        };
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

      # TODO: use?
      /*
        packages.x86_64-linux.frameworkISO = nixos-generators.nixosGenerate {
        pkgs = unstable.legacyPackages.x86_64-linux;
        modules = [ nixos-hardware.nixosModules.framework-11th-gen-intel ];
        format = "iso";
        };
      */

      # TODO: move to Phaer's thing
      packages.x86_64-linux.digitalOceanImage = nixos-generators.nixosGenerate {
        pkgs = unstable.legacyPackages.x86_64-linux;
        modules = [
          ./configs/arianvp.me
        ];
        format = "do";
      };

      nixosConfigurations =
        let
          modules = with self.nixosModules; [
            base
            inputs
            cgroup-exporter.nixosModules.default
            dnssd
            direnv
            overlays
          ];
        in
        {
          framework = unstable.lib.nixosSystem {
            modules = modules ++ [
              nixos-hardware.nixosModules.framework-11th-gen-intel
              lanzaboote.nixosModules.lanzaboote
              ./configs/framework/configuration.nix
            ];
          };
          utm = stable.lib.nixosSystem {
            modules = modules ++ [
              { networking.hostName = "utm"; }
              ./configs/utm/configuration.nix
            ];
          };
          altra = unstable.lib.nixosSystem {
            modules = modules ++ [ ./configs/altra/configuration.nix ];
          };
          arianvp-me = unstable.lib.nixosSystem {
            modules = modules ++ [
              ./configs/arianvp.me
            ];
          };
        };
    };
}
