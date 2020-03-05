{ config, pkgs, lib, modulesPath, ... }: {
  imports = [
    ../../modules/yubikey
    ../../modules/ssh-tweaks.nix
    ../../modules/env.nix
    ../../modules/cachix.nix
    ../../modules/hie.nix
    ../../modules/containers-v2.nix
    (modulesPath + "/installer/scan/not-detected.nix")
  ];
  config = {
    nix.extraOptions = ''
    '';
    virtualisation.docker.enable = true;
    virtualisation.libvirtd.enable = true;
    time.timeZone = "Europe/Amsterdam";
    programs.bash.enableCompletion = true;
    hardware.pulseaudio.enable = true;
    systemd.additionalUpstreamSystemUnits = [ "systemd-portabled.service" ];

    fonts.fonts = [ pkgs.apl385 pkgs.noto-fonts pkgs.noto-fonts-emoji ];
    users.users.arian = {
      isNormalUser = true;
      createHome = true;
      extraGroups = [ "docker" "wheel" ];
    };
    environment.gnome3.excludePackages = with pkgs.gnome3; [ gnome-software ];


    services.systemd-nspawn.machines = {
      "test1".config = { ... }: {
        services.nginx.enable = true;
        networking.firewall.allowedTCPPorts = [ 80 ];
        systemd.network.networks."80-container-host0".networkConfig.Address = "192.168.33.2";
      };
      "test2".config = { ... }: {
        networking.firewall.allowedTCPPorts = [ 80 ];
        services.nginx.enable = true;
      };
    };
    services.xserver = {
      enable = true;
      desktopManager.gnome3 = {
        enable = true;
      };
      displayManager.gdm.enable = true;
    };
    environment.systemPackages = [
      pkgs.user-environment
      pkgs.gnomeExtensions.dash-to-panel
      pkgs.gnome3.gnome-tweaks
      pkgs.gnome3.gnome-shell-extensions
    ];
    environment.interactiveShellInit = ''
      if [[ "$VTE_VERSION" > 3405 ]]; then
        source "${pkgs.gnome3.vte}/etc/profile.d/vte.sh"
      fi
    '';

    networking.hostName = "t490s";
    system.stateVersion = "18.03";

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    nix.maxJobs = lib.mkDefault 8;
    powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

    services.printing = {
      enable = true;
      drivers = [ pkgs.hplip ];
    };

    services.hardware.bolt.enable = true;
    services.tlp.enable = true;

    boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" ];
    boot.kernelModules = [ "kvm-intel" ];

    # /boot will be automatically mounted by gpt-auto-generator, which is
    # enabled by default

    boot.initrd.luks.devices."root".device = "/dev/disk/by-partuuid/9f5a793b-d57a-4adc-a0d7-6b6db7c97031";
    fileSystems = {
      "/" = {
        device = "/dev/mapper/root";
        fsType = "btrfs";
        options = [ "noatime" "nodiratime" "compress=zstd" "discard" "defaults" ];
      };
    };
  };


}
