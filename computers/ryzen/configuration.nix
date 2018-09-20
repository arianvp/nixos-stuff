{ pkgs, config, ... }:
with pkgs;
{
  imports = [ 
    ./hardware-configuration.nix
    ../../modules/yubikey
    ../../modules/steam-support.nix
  ];

  nixpkgs.config.allowUnfree = true;
 
  boot.kernelModules = [ "kvm-intel" "kvm-amd" ];
  boot.kernelParams = ["amdgpu.dc=1"];

  boot.kernelPackages = pkgs.linuxPackages_4_17;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.pulseaudio.enable = true;
  hardware.u2f.enable = true;
  services.sshd.enable = true;

  networking.hostName = "ryzen";

  time.timeZone = "Europe/Amsterdam";


  environment.systemPackages = [ 
    dmenu dzen2 arc-theme arc-icon-theme ntfs3g
  ];

  # This is needed for my Yubikey
  services.pcscd.enable = true;

  services.ipfs.enable = false;

  fonts.fonts = with pkgs; [ fira-code ];

  services.urxvtd.enable = true;

  environment.gnome3.excludePackages = with pkgs.gnome3; optionalPackages;
  services.xserver =  {
    enable = true;
    desktopManager.gnome3 = {
      enable = true;
    };
    displayManager.gdm.enable = true;
  };

  /*services.xserver = {
    enable = true;
    windowManager = {
      xmonad = {
        enable = true;
        enableContribAndExtras = true;
      };
      default = "xmonad";
    };
    desktopManager = { default = "none"; xterm.enable = false; };
  };*/

  users.extraUsers.arian = {
     isNormalUser = true;
     uid = 1000;
     extraGroups = ["wheel" "audio"];
     # Root of trust is that we trust Github not to fuck this up :)
     openssh.authorizedKeys.keyFiles = [ (builtins.fetchurl "https://github.com/arianvp.keys") ];
   };

  # Never change this value unless instructed to.
  system.stateVersion = "18.03"; 
}

