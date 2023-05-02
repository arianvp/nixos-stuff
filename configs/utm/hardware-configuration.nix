# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ ];

  boot.initrd.availableKernelModules = [ "virtio_pci" "xhci_pci" "usb_storage" "usbhid" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  systemd.repart.partitions = {
    "00-esp" = {
      Type = "esp";
      SizeMaxBytes = "1G";
      Format = "vfat";
    };
    "10-root" = {
      Type = "root";
      Format = "btrfs";
    };
  };


  # Handled by gpt-auto-generator
  # TODO: Can't leave empty because NixOS complains
  fileSystems."/" =
    {
      device = "/dev/disk/by-partlabel/root-arm64";
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-partlabel/esp";
    };

  fileSystems."/mnt" =
    {
      device = "share";
      fsType = "virtiofs";
    };

  swapDevices = [ ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = false;
  networking.useNetworkd = lib.mkDefault true;

  systemd.network.networks.main = {
    matchConfig.Name = "en*";
    networkConfig = {
      DHCP = "yes";
      MulticastDNS = "yes";
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
