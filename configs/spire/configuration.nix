{ modulesPath, ... }:
{

  imports = [
    ../../modules/spire/server.nix
    "${modulesPath}/virtualisation/amazon-image.nix"
  ];

  networking.firewall.allowedTCPPorts = [
    22
    443
    8081
  ];

  spire.server = {
    enable = true;
    trustDomain = "frickel.consulting";
  };

  nixpkgs.hostPlatform = "aarch64-linux";
}
