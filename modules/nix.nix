{ pkgs, ... }:
{
  nix.package = pkgs.lixPackageSets.lix_2_94.lix;

  nix.settings.substituters = [
    # "https://nixos.snix.store?priority=39"  # lots of issues with lix
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
    "fetch-closure"
  ];

  nix.settings.use-cgroups = true;

  users.groups.nix-trusted-users = { };
}
