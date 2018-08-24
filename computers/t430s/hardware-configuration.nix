{ config, lib, pkgs, ... }: {
  imports =
    [ <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
      ./rootfs.nix
    ];

  boot.initrd.availableKernelModules = [
    "xhci_pci" "ehci_pci" "ahci" 
    "usb_storage" "sd_mod" "sdhci_pci"
  ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  boot.initrd.luks.devices.cryptroot = {
    device = "/dev/disk/by-uuid/44a0e451-421a-4f36-a183-39e0d3968304";
    allowDiscards = true;
  };

  arian.rootfs.device = "/dev/mapper/cryptroot";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/0971-C174";
    fsType = "vfat";
  };

 
  swapDevices = [ ];

  nix.maxJobs = lib.mkDefault 4;
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
}
