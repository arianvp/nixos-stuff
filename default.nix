{ ... }:
let
  cfg = {
    overlays = map import [
      ./deployments.nix
      ./overlays/neovim.nix
      ./overlays/user-environment.nix
      ./overlays/fonts.nix
      ./overlays/pkgs.nix
      ./overlays/wire.nix
      # ./overlays/ormolu.nix
    ] ++ [ nivOverlay ];
    config = {
      allowUnfree = true;
    };
  };
  sources = import ./nix/sources.nix;
  nivOverlay = self: super: {
   gitignore = import sources."gitignore.nix" { lib = super.lib; };
  };
  pkgs = import sources.nixpkgs;
in
pkgs cfg
