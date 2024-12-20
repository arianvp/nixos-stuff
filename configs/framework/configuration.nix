  { pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./pcrlock.nix
  ];
  services.fwupd.enable = true;

  boot.initrd.systemd.enable = true;
  # console.earlySetup = lib.mkForce false;
  # boot.consoleLogLevel = 3;
  boot.kernelParams = [
    # "rd.systemd.show_status=auto" "rd.udev.log_level=3" "vt.global_cursor_default=0"
  ];

  boot.initrd.systemd.services.initrd-cleanup = {
    serviceConfig.ExecStart = [ "" "/bin/true" ];
    unitConfig.OnSuccess = "emergency.target";
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;
  # boot.loader.systemd-boot.enable = true;
  boot.lanzaboote.enable = true;
  boot.lanzaboote.pkiBundle = "/etc/secureboot";
  boot.loader.efi.canTouchEfiVariables = true;

  boot.extraModprobeConfig = ''
    options iwlwifi disable_11ax=Y
  '';

  networking.hostName = "framework";
  services.xserver.enable = true;
  services.openssh.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  environment.variables = {
    MOZ_ENABLE_WAYLAND = "1";
  };
  environment.systemPackages = with pkgs; [
    chromium
    neovim
    gnome-builder
    flatpak-builder
    yubioath-flutter
  ];
  services.flatpak.enable = true;

  users.users.arian = {
    isNormalUser = true;
    createHome = true;
    extraGroups = [ "wheel"  "tss" ];
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBMaGVuvE+aNyuAu0E9m5scVhmnVgAutNqridbMnc261cHQwecih720LCqDwTgrI3zbMwixBuU422AK0N81DyekQ="
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBGVpzxBOwLIuy/2jjNoec7YfRHtwImf8688srJXaIRiyA4ye6/Ik8lWDTzzB4+V3rfekK0cx7w5gCOrKaqDRvVc="
    ];
  };



  services.fprintd.enable = false;

  
  programs.chromium.enable = true;

  system.stateVersion = "21.11"; # Did you read the comment?
}

