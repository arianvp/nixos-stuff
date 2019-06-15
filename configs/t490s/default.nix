{ config, pkgs, lib, modulesPath, ... }: {
  imports = [
    ../../modules/yubikey
    ../../modules/ssh-tweaks.nix
    ../../modules/env.nix
    (modulesPath + "/installer/scan/not-detected.nix")
  ];
  config = {
    time.timeZone = "Europe/Amsterdam";
    programs.bash.enableCompletion = true;
    hardware.pulseaudio.enable = true;
    users.users.arian = {
      isNormalUser = true;
      createHome = true;
      extraGroups = [ "wheel" ];
    };
    environment.gnome3.excludePackages = with pkgs.gnome3; [ gnome-software ];
    services.xserver =  {
      enable = true;
      desktopManager.gnome3 = {
        enable = true;
      };
      displayManager.gdm.enable = true;
    };
    environment.interactiveShellInit = ''
      if [[ "$VTE_VERSION" > 3405 ]]; then
        source "${pkgs.gnome3.vte}/etc/profile.d/vte.sh"
      fi
    '';

    networking.hostName = "t490s";
    system.stateVersion = "19.03";


    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    nix.maxJobs = lib.mkDefault 8;
    powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";


    boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" ];
    boot.kernelModules = [ "kvm-intel" ];

    boot.initrd.luks.devices."root".device = "/dev/gpt-auto-luks";

    fileSystems = {
      "/" = {
        device = "/dev/gpt-auto";
        fsType = "btrfs";
        options = [ "noatime" "nodiratime" "compress=zstd" "discard" "defaults" ];
      };
      "/boot" = {
        device = "/dev/disk/by-partuuid/1bc32aff-296f-4a18-aec0-41d72e2a9d43";
        fsType = "vfat";
      };
    };
  };
}
