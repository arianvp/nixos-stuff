let
  cfg = {
    overlays = map (n: import n) [
      ./deployments.nix
      ./overlays/neovim.nix
      ./overlays/user-environment.nix
      ./overlays/fonts.nix
    ];
    config = {
      allowUnfree = true;
    } ;
  };
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs;
in
  pkgs cfg
