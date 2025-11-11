{
  inputs.nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  outputs = { self, nixpkgs }: {
    nixosConfigurations = {
      foo = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
      };
      bar = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
      };
    };
  }
}
