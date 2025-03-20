{ modulesPath, ... }:
{

  imports = [
    ../../modules/spire/server.nix
    "${modulesPath}/virtualisation/amazon-image.nix"
  ];

  networking.hostName = "ec2-54-221-118-58.compute-1.amazonaws.com";

  spire.server = {
    enable = true;

    trustDomain = "ec2-54-221-118-58.compute-1.amazonaws.com";
  };

  nixpkgs.hostPlatform = "aarch64-linux";
}
