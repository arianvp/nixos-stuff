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
    time.timeZone = "Europe/Amsterdam";
    programs.bash.enableCompletion = true;
    hardware.pulseaudio.enable = true;
    virtualisation.docker.enable = true;
    users.users.arian = {
      isNormalUser = true;
      createHome = true;
      extraGroups = [ "wheel" ];
    };
    environment.gnome3.excludePackages = with pkgs.gnome3; [ gnome-software ];
    environment.systemPackages = [ pkgs.vscode  pkgs.chromium pkgs.neovim ];
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
