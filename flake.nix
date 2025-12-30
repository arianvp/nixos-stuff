{
  description = "Arian's computers";
  inputs.unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";
  inputs.stable.url = "github:NixOS/nixpkgs/nixos-25.05";
  inputs.nixos-hardware.url = "github:NixOS/nixos-hardware";
  inputs.lanzaboote = {
    url = "github:nix-community/lanzaboote";
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
      ...
    }:
    {

      devShells = unstable.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (
        system: with unstable.legacyPackages.${system}; {
          default = mkShell {
            packages = [
              doctl
              opentofu
              dnscontrol
            ];
          };
        }
      );

      overlays.spire = import ./overlays/spire.nix;

      nixosModules = {
        cachix = ./modules/cachix.nix;
        direnv = ./modules/direnv.nix;
        diff = ./modules/diff.nix;
        dnssd = ./modules/dnssd.nix;
        monitoring = ./modules/monitoring.nix;
        prometheus = ./modules/prometheus.nix;
        alertmanager = ./modules/alertmanager.nix;
        grafana = ./modules/grafana.nix;
        opentelemetry-collector = ./modules/opentelemetry-collector.nix;
        spire-server = ./modules/spire/server.nix;
        spire-agent = ./modules/spire/agent.nix;
        spire-controller-manager = ./modules/spire/controller-manager.nix;
        inputs = {
          _module.args.inputs.self = self;
        };
        overlays =
          { pkgs, ... }:
          {
            # nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = map import [
              ./overlays/fonts.nix
              ./overlays/neovim.nix
              ./overlays/spire.nix
              ./overlays/openssh-audit.nix
              ./overlays/gnome-ssh-askpass4.nix
            ];
          };
      };

      packages = unstable.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (
        system:
        let
          pkgs = unstable.legacyPackages.${system}.extend (import ./overlays/spire.nix);
        in
        {
          inherit (pkgs) spire-controller-manager spire-tpm-plugin spire;
        }
      );

      checks = unstable.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
        system:
        let
          pkgs = unstable.legacyPackages.${system}.extend (import ./overlays/spire.nix);
          lib = unstable.lib;

          # Recursively find all _test.nix files in a directory
          # Returns list of { name, path } attrs
          findTestsIn = baseDir: relPath:
            let
              fullPath = baseDir + relPath;
              entries = builtins.readDir fullPath;

              processEntry = name: type:
                let
                  newRelPath = relPath + "/${name}";
                in
                if type == "directory" then
                  findTestsIn baseDir newRelPath
                else if type == "regular" && lib.hasSuffix "_test.nix" name then
                  let
                    testPath = baseDir + newRelPath;
                    # Import the test file to read its name attribute
                    testConfig = import testPath;
                    testName = testConfig.name or (lib.removeSuffix "_test.nix" (lib.removePrefix "/" newRelPath));
                  in
                  [{
                    name = testName;
                    path = testPath;
                  }]
                else
                  [];
            in
            lib.flatten (lib.mapAttrsToList processEntry entries);

          # Find all module tests
          moduleTests = findTestsIn ./modules "";

          # Convert to attribute set of checks
          discoveredChecks = builtins.listToAttrs (map (test: {
            name = test.name;
            value = pkgs.testers.runNixOSTest {
              imports = [ test.path ];
            };
          }) moduleTests);

        in
        # Merge manually defined tests with discovered module tests
        {
          spire-join-token = pkgs.testers.runNixOSTest {
            imports = [ ./tests/spire-join-token.nix ];
          };
          spire-http-challenge = pkgs.testers.runNixOSTest {
            imports = [ ./tests/spire-http-challenge.nix ];
          };
          spire-tpm = pkgs.testers.runNixOSTest {
            imports = [ ./tests/spire-tpm.nix ];
          };
          bootloader = pkgs.testers.runNixOSTest {
            imports = [ ./modules/bootloader/test.nix ];
          };
        } // discoveredChecks
      );

      /*
        nodes =
        (unstable.lib.evalModules {
          modules = [
            ./modules/nodes
          ];
        }).config.nodes;
      */

      nixosConfigurations =
        let
          modules = with self.nixosModules; [
            inputs
            dnssd
            cgroup-exporter.nixosModules.default
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
            modules = modules ++ [
              nixos-hardware.nixosModules.asrock-rack-altrad8ud-1l2t
              ./configs/altra/configuration.nix
            ];
          };
          arianvp-me = unstable.lib.nixosSystem {
            modules = modules ++ [
              ./configs/arianvp.me
            ];
          };
        };
    };
}
