{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix 
    ./yubikey.nix
  ];
  time.timeZone = "Europe/Amsterdam";
  environment.systemPackages = with pkgs; [ vimHugeX firefox ];
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
  system.stateVersion = "18.03"; 
}
