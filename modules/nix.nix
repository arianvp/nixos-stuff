{ pkgs, ... }:
{
  nix.package = pkgs.lixPackageSets.lix_2_93.lix;

  nix.settings.substituters = [
    "https://nixos.snix.store?priority=39"
    "https://cache.nixos.org?priority=40"
  ];

  nix.settings.trusted-users = [
    "@wheel"
    "@nix-trusted-users"
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "cgroups"
  ];

  nix.settings.use-cgroups = true;
}
