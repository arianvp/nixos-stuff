{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/yubikey
    ../../modules/ssh-tweaks.nix
  ];
  config = {
    time.timeZone = "Europe/Amsterdam";
    boot.kernelPackages = pkgs.linuxPackages_latest;
    programs.bash.enableCompletion = true;
    hardware.pulseaudio.enable = true;
    virtualisation.docker.enable = true;
    users.users.arian = {
      isNormalUser = true;
      createHome = true;
      extraGroups = [ "wheel" "docker" ];
    };
    environment.gnome3.excludePackages = with pkgs.gnome3; [ gnome-software ];

    environment.variables.EDITOR = "nvim";

    networking.networkmanager.wifi.scanRandMacAddress = false;
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
    networking.hostName = "t430s";
    system.stateVersion = "18.03";
  };
}
