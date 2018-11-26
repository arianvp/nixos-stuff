{ pkgs, config, ... }:
with pkgs;
{
  imports = [ 
    ./hardware-configuration.nix
    ../../modules/yubikey
    ../../modules/steam-support.nix
    ../../modules/gitlab-runner.nix
    ../../modules/containers-v2.nix
  ];

  programs.ssh.startAgent = true;

  nixpkgs.config.allowUnfree = true;


  boot.kernelPackages = pkgs.linuxPackages_4_18;
  boot.kernelModules = [ "kvm-intel" "kvm-amd" ];
  boot.kernelParams = ["amdgpu.dc=1"]; networking.firewall.enable = false;
  networking.firewall.allowedTCPPorts = [ 51413 27950 27952 27960 27965 ];
  networking.firewall.allowedUDPPorts = [ 27950 27952 27960 27965 ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.pulseaudio.enable = true;

  networking.hostName = "ryzen";
  networking.useNetworkd = true;

  time.timeZone = "Europe/Amsterdam";

  services.fwupd.enable = true;

  environment.systemPackages = [ 
    arc-theme arc-icon-theme ntfs3g  rofi
  ];

  systemd.targets."multi-user".wants = [ "machines.target" ];

  services.systemd-nspawn.machines.arian = {
    config = {...}: {
      services.nginx.enable = true;
    };
  };

  services.ipfs.enable = false;

  fonts.fonts = with pkgs; [ fira-code ];

  services.urxvtd.enable = true;

  services.xserver = {
    enable = true;
    windowManager = {
      xmonad = {
        enable = true;
        enableContribAndExtras = true;
      };
      default = "xmonad";
    };
    desktopManager = { default = "none"; xterm.enable = false; };
  };

  users.extraUsers.arian = {
     isNormalUser = true;
     uid = 1000;
     extraGroups = ["wheel" "audio"];
   };

  # Never change this value unless instructed to.
  system.stateVersion = "18.03"; 
}

