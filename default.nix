{ ... } @ args:
let 
  cfg = {
    overlays = map (n: import n) [
      ./deployments.nix
      ./overlays/neovim.nix
      ./overlays/user-environment.nix
    ];
    config = { 
      allowUnfree = true; 
    }; 
  };
  channels_ = builtins.fromJSON (builtins.readFile ./nixpkgs.json);
  fork = import ../nixos/nixpkgs (args // cfg);
  channel = channels."nixos-19.03";
  channels  = builtins.mapAttrs (k: v: import (builtins.fetchGit v) (args // cfg)) channels_;
in 
  channels."nixos-19.03" // { inherit channels fork; }
