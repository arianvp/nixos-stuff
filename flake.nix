{
  description = "A flake for building Hello World";

  inputs.nixpkgs.url = "github:nixos/nixpkgs-channels/nixos-20.03";

  outputs = { self, nixpkgs }:
    let
      # Flakes have a magic `outPath` attribute; which makes importing work
      lib = nixpkgs.lib;
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = map import [
          ./deployments.nix
          ./overlays/neovim.nix
          ./overlays/user-environment.nix
          ./overlays/fonts.nix
          ./overlays/pkgs.nix
          ./overlays/wire.nix
        ];
      };
    in
      {
        nixosConfigurations = {
          "arianvp" = pkgs.nixos (import ./configs/arianvp.me);
          "t490s" = pkgs.nixos (import ./configs/t490s);
          "ryzen" = pkgs.nixos (import ./configs/ryzen);
        };
      };
}
