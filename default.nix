let 
  channels = builtins.fromJSON (builtins.readFile ./nixpkgs.json);
  channel = channels."nixos-19.03";
  nixpkgs_ = (builtins.fetchGit channel);
in 
  { nixpkgs ? nixpkgs_}: import nixpkgs { 
    overlays = map (n: import n) [
      ./deployments.nix
      ./overlays/neovim.nix
      ./overlays/user-environment.nix
    ];
    config = { 
      allowUnfree = true; 
    }; 
  }
