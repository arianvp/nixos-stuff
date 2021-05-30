{ pkgs, config, lib, ... }:
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

  services.avahi = {
    enable = true;
    nssmdns = true;
    publish = {
      enable = true;
      domain = true;
      addresses = true;
      userServices = true;
      workstation = true;
    };
  };

  services.resolved.enable = true;

  services.openssh.enable = true;
  cluster.kubernetes.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  services.xserver = {
    enable = true;
    desktopManager.gnome3 = {
      enable = true;
    };
    displayManager.gdm.enable = true;
  };

  nix.package = pkgs.nixFlakes;
  nix.trustedUsers = [ "arian" ];
  users.extraUsers.arian = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" "audio" ];
    openssh.authorizedKeys.keyFiles = [
      (
        pkgs.fetchurl {
          url = "https://github.com/arianvp.keys";
          sha256 = "sha256-AeabXoMSq73ZhQE8m6fvdGWX7pGN4pL/3budKwpeGqk=";
        }
      )
    ];
  };

  services.minidlna = {
    enable = true;
    mediaDirs = [ "/home/arian/Downloads" ];
  };
  systemd.services.minidlna.serviceConfig.User = lib.mkForce "arian";

  environment.systemPackages = [ pkgs.neovim ];

  # Never change this value unless instructed to.
  system.stateVersion = "18.03";
}
