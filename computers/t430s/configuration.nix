{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix 
   ../../modules/yubikey
   ../../modules/ssh-tweaks.nix
  ];
  time.timeZone = "Europe/Amsterdam";
  environment.systemPackages = with pkgs; [ vimHugeX firefox ];
  programs.bash.enableCompletion = true;
  hardware.pulseaudio.enable = true;
  users.users.root = {
    openssh.authorizedKeys.keyFiles = [ (builtins.fetchurl "https://github.com/arianvp.keys" )];
  };
  users.users.arian = {
    isNormalUser = true;
    createHome = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keyFiles = [ (builtins.fetchurl "https://github.com/arianvp.keys" )];
  };
  environment.gnome3.excludePackages = with pkgs.gnome3; [ gnome-software ];
  services.xserver =  {
    enable = true;
    desktopManager.gnome3 = {
      enable = true;
    };
    displayManager.gdm.enable = true;
  };

  networking.hostName = "t430s";
  services.sshd.enable = true;
  system.stateVersion = "18.03"; 
}
