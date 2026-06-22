{
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./diff.nix
    ./dnssd.nix
    ./monitoring.nix
    ./nix.nix
    ./ssh.nix
  ];

  environment.systemPackages = [ pkgs.ghostty ];

  documentation.man = {
    enable = true;
    cache.enable = true;
  };

  users.users.arian = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "nix-trusted-users"
    ];
  };
}
