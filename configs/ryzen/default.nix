{ pkgs, config, ... }:
with pkgs;
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/yubikey
    ../../modules/direnv.nix
  ];

  programs.ssh.startAgent = true;

  boot.kernelModules = [ "kvm-intel" "kvm-amd" ];

  # :boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.kernelParams = [
    "systemd.unified_cgroup_hierarchy=1"
  ];

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
  fonts.fonts = [ pkgs.apl385 pkgs.noto-fonts pkgs.noto-fonts-emoji ];


  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  services.xserver = {
    enable = true;
    desktopManager.gnome3 = {
      enable = true;
    };
    #displayManager.gdm.enable = true;
    displayManager.lightdm.enable = true;
  };
  environment.systemPackages = [
    pkgs.user-environment
    pkgs.gnomeExtensions.dash-to-panel
    pkgs.gnome3.gnome-tweaks
    pkgs.gnome3.gnome-shell-extensions
    pkgs.nodejs-12_x
  ];

  nix.trustedUsers = [ "arian" ];
  users.extraUsers.arian = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" "audio" "docker" ];

    openssh.authorizedKeys.keys = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIDXJypxL7B7Pl4WS4Suv654AguJMhYjKBPhTQNLRsBOgAAAABHNzaDo= ssh:"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAICUTTzP5D0bLXRqGkw3ujx9ihqAYVC/Tz8RBz06FCeh0AAAABHNzaDo= ssh:"
    ];
  };

  # Never change this value unless instructed to.
  system.stateVersion = "18.03";
}
