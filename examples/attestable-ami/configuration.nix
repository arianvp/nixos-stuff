# The appliance: generic building blocks from ./modules, the EC2 specifics, and
# the workload.
{ lib, guest, ... }:
{
  imports = [
    ./modules/nitro-sandbox-parent.nix
    ./modules/appliance.nix
    ./modules/boot-state.nix
    ./modules/lockdown.nix
    ./modules/ec2.nix
    ./modules/imds.nix
    ./modules/kms-decrypt.nix
    ./modules/tls-identity.nix
    ./modules/nitrotpm.nix
  ];

  image.modules.attestable-ami.imports = [
    ./modules/single-uki.nix
    ./modules/ipe.nix
  ];

  system.image = {
    id = "attestable-ami";
    version = "1";
  };

  # Not needed on EC2, but lets the test boot the very image that gets uploaded.
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
  ];

  security.lockdown = "confidentiality";

  # Decrypts the `kms.example` credential from the user data to
  # /run/kms-decrypt/example.
  services.kms-decrypt = {
    keyId = lib.fileContents ./kms-key-arn.txt;
    secrets.example = { };
  };

  services.nitro-sandbox.guest = guest.config.system.build.nitro-sandbox;

  # NitroTPM measures into the SHA-384 bank.
  services.log-boot-state.pcrBank = "sha384";

  nixpkgs.overlays = [
    (final: prev: { nitrotpm-tools = final.callPackage ./nitrotpm-tools.nix { }; })
  ];

  system.stateVersion = "26.05";
}
