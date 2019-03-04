{ config, pkgs, ... }: 
{
  imports = [
    ./hardware-configuration.nix 
   ../../modules/yubikey
   ../../modules/ssh-tweaks.nix
   ../../modules/env.nix
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
    services.netdata.enable = true;
    networking.hostName = "t430s";
    services.sshd.enable = true;
    system.stateVersion = "18.03"; 
  };
}
