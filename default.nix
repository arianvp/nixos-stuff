let 
  channels = builtins.fromJSON (builtins.readFile ./nixpkgs.json);
  channel = channels."nixos-19.03";
  nixpkgs = import (builtins.fetchGit channel);
in 
  nixpkgs { 
    overlays = map (n: import n) [
      ./overlays/deployments.nix
      ./overlays/neovim.nix
      ./overlays/user-environment.nix
    ];
    config = { 
      allowUnfree = true; 
    }; 
  }
