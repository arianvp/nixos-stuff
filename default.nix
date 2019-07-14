let 
  channels_ = builtins.fromJSON (builtins.readFile ./nixpkgs.json);
  channel = channels."nixos-19.03";
  channels  = builtins.mapAttrs (k: v: import (builtins.fetchGit v) {
    overlays = map (n: import n) [
      ./deployments.nix
      ./overlays/neovim.nix
      ./overlays/user-environment.nix
    ];
    config = { 
      allowUnfree = true; 
    }; 

  }) channels_;
in 
  channels."nixos-19.03"
