{ config, pkgs, lib, ... }: {
  imports = [
    ./hardware-configuration.nix
  ];

  services.cachix-agent.enable = true;
  environment.systemPackages = [ pkgs.cachix ];

  boot.initrd.verbose = false;
  boot.initrd.systemd.enable = true;
  console.earlySetup = lib.mkForce false;
  boot.consoleLogLevel = 3;
  boot.kernelParams = [ "quiet" "rd.systemd.show_status=auto" "rd.udev.log_level=3" "vt.global_cursor_default=0" ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.extraModprobeConfig = ''
    options iwlwifi disable_11ax=Y
  '';

  networking.hostName = "framework";
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  environment.variables = {
    MOZ_ENABLE_WAYLAND = "1";
  };
  environment.gnome.excludePackages = with pkgs.gnome; [
    geary
    epiphany
    gnome-calendar
    gnome-contacts
    gedit
  ];

  users.users.arian = {
    isNormalUser = true;
    createHome = true;
    extraGroups = [ "wheel" ];
  };
  virtualisation.podman.enable = true;
  virtualisation.podman.dockerCompat = true;
  virtualisation.podman.dockerSocket.enable = true;
  virtualisation.cri-o.enable = true;
  system.stateVersion = "21.11"; # Did you read the comment?
}

