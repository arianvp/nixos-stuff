{ pkgs, config, ... }:
with pkgs;
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/yubikey
  ];

  programs.ssh.startAgent = true;

  boot.kernelModules = [ "kvm-intel" "kvm-amd" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.pulseaudio.enable = true;

  networking.hostName = "ryzen";

  time.timeZone = "Europe/Amsterdam";

  services.resolved = {
    enable = true;
    extraConfig = ''
    MulticastDNS=yes
    '';
  };

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

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
     openssh.authorizedKeys.keyFiles = [
    (pkgs.fetchurl {
      url = "https://github.com/arianvp.keys";
      sha256 = "0m9qpkn0hf5cddz145yc8ws5bmbzxa296hsgzw15p3kw1ramdipq";
    })
      ];
   };

  # Never change this value unless instructed to.
  system.stateVersion = "18.03";
}

