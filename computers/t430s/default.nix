{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix 
    ../../modules/yubikey
    ../../modules/ssh-tweaks.nix
    ../../modules/env.nix
    ../../modules/containers-v2.nix
    ../../modules/direnv.nix
  ];
  config = {

    services.systemd-nspawn.machines = {
      "nginx".config = {...}: {
        services.nginx.enable = true;
      };
    };

    /*networking.extraHosts = ''
      0.0.0.0 twitter.com
      0.0.0.0 reddit.com
      0.0.0.0 facebook.com
      0.0.0.0 news.ycombinator.com
      0.0.0.0 tweakers.net
    '';*/

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
    services.netdata.enable = true;
    networking.hostName = "t430s";
    services.sshd.enable = true;
    system.stateVersion = "18.03"; 
  };
}
