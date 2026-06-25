{ pkgs, ... }:
{
  nix.package = pkgs.lixPackageSets.latest.lix;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
      "cgroups"
      "auto-allocate-uids"
    ];

    substituters = [
      # "https://nixos.snix.store?priority=39"  # lots of issues with lix
      "https://cache.nixos.org?priority=40"
    ];

    allowed-users = [
      "@wheel"
      "@nix-trusted-users"
    ];

    trusted-users = [
      "@wheel"
      "@nix-trusted-users"
    ];

    system-features = [ "uid-range" ];

    auto-allocate-uids = true;
    use-cgroups = true;

  };

  nix.gc = {
    automatic = true;
    dates = [ "13:00" ];
  };

  nix.optimise.automatic = true;

  users.groups.nix-trusted-users = { };
}
