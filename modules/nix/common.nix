{ pkgs, ... }:
{
  nix.enable = true;
  nix.package = pkgs.lixPackageSets.latest.lix;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    substituters = [
      "https://nixos.snix.store?priority=39" # lots of issues with lix
    ];

    allowed-users = [ "@wheel" ];
    trusted-users = [ "@wheel" ];
  };

  nix.gc.automatic = true;
  nix.optimise.automatic = true;
}
