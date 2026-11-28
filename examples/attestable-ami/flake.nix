{
  description = "An attestable EC2 AMI whose NitroTPM measurements are known at build time";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (self.nixosConfigurations.appliance.config.system.build.images) attestable-ami;
    in
    {
      nixosConfigurations.appliance = nixpkgs.lib.nixosSystem {
        modules = [
          ./configuration.nix
          { nixpkgs.hostPlatform = system; }
        ];
      };

      packages.${system} = {
        default = attestable-ami;
        inherit (attestable-ami.passthru.config.system.build) pcrs;
        create-ami = pkgs.callPackage ./create-ami.nix { image = attestable-ami; };
        predict-pcr12 = pkgs.callPackage ./predict-pcr12.nix { };
        e2e = pkgs.callPackage ./e2e.nix {
          appliance = self.nixosConfigurations.appliance;
          inherit (self.packages.${system}) predict-pcr12;
        };
      };

      checks.${system}.measured-boot = pkgs.testers.runNixOSTest {
        imports = [ ./test.nix ];
        _module.args = {
          appliance = self.nixosConfigurations.appliance;
          inherit (self.packages.${system}) predict-pcr12;
        };
      };
    };
}
