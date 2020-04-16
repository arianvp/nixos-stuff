let
  cfg = {
    overlays = [
      import ./deployments.nix

      # Replace with: To remove infinite recursion
      # (import ./deployments.nix)

      /*./overlays/neovim.nix
      ./overlays/user-environment.nix
      ./overlays/fonts.nix
      ./overlays/pkgs.nix
      ./overlays/ormolu.nix */
    ];
    config = {
      allowUnfree = true;
    } ;
  };
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs;
in
  pkgs cfg
