{ config, pkgs, lib, modulesPath, ... }: {
  imports = [
    ../../modules/yubikey
    ../../modules/ssh-tweaks.nix
    ../../modules/env.nix
    ../../modules/cachix.nix
    ../../modules/hie.nix
    ../../modules/direnv.nix
    ../../modules/containers-v2.nix
    (modulesPath + "/installer/scan/not-detected.nix")
  ];
  config = {
    systemd.package = pkgs.systemdPatched;
    boot.kernelPackages = pkgs.linuxPackages_5_4;
    boot.kernelParams = [ "quiet" "loglevel=3" "vga=current" ];
    nix.extraOptions = ''
      experimental-features = nix-command flakes
    '';
    nix.package = pkgs.nix_2_4;
    nix.distributedBuilds = true;
    nix.buildMachines = [
      {
        hostName = "ryzen.local";
        sshUser = "arian";
        sshKey = "/root/.ssh/id_ed25519";
        system = "x86_64-linux";
        supportedFeatures = [ "big-parallel" ];
        maxJobs = 8;
      }
    ];
    virtualisation.docker.enable = true;
    virtualisation.libvirtd.enable = true;
    time.timeZone = "Europe/Amsterdam";
    programs.bash.enableCompletion = true;
    programs.gnupg.agent.enable = true;
    hardware.pulseaudio.enable = true;
    hardware.opengl.enable = true;
    services.avahi.nssmdns = true;
    services.nginx.enable = true;
    networking.firewall.allowedTCPPorts = [ 80 ];

    systemd.additionalUpstreamSystemUnits = [
      "systemd-userdbd.socket"
      "systemd-userdbd.service"
    ];
    systemd.sockets.systemd-userdbd.wantedBy = [ "sockets.target" ];


    services.tailscale.enable = true;

    fonts.fonts = [ pkgs.apl385 pkgs.noto-fonts pkgs.noto-fonts-emoji ];
    users.users.arian = {
      isNormalUser = true;
      createHome = true;
      extraGroups = [ "docker" "wheel" ];
    };
    environment.gnome3.excludePackages = with pkgs.gnome3; [ gnome-software geary ];
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
      pkgs.tailscale
      pkgs.wire-desktop-internal
    ];
    environment.interactiveShellInit = ''
      if [[ "$VTE_VERSION" > 3405 ]]; then
        source "${pkgs.vte}/etc/profile.d/vte.sh"
      fi
    '';

    networking.hostName = "t490s";
    system.stateVersion = "18.03";

    security.pam.u2f.enable = true;

    security.pam.u2f.cue = true;

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    nix.maxJobs = lib.mkDefault 8;
    powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

    services.printing = {
      enable = true;
      drivers = [ pkgs.hplip ];
    };

    services.hardware.bolt.enable = true;

    boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usbhid" ];
    boot.kernelModules = [ "kvm-intel" ];

    # /boot will be automatically mounted by gpt-auto-generator, which is
    # enabled by default

    # not needed.   root will be automatically mounted by gpt-auto-generator
    boot.initrd.luks.devices."root".device = "/dev/disk/by-uuid/0c642ebc-2b76-43dc-b9ba-34f1125d7f16";
    fileSystems = {
      "/" = {
        device = "/dev/mapper/root";
        fsType = "btrfs";
        options = [ "noatime" "nodiratime" "compress=zstd" "discard" "defaults" ];
      };
    };
  };


}
