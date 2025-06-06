{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./pcrlock.nix
    ./audit.nix
  ];
  services.fwupd.enable = true;

  fileSystems = {
    "/tmp" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "nosuid" "nodev" "noexec" "size=4G" ];
    };
  };

  boot.initrd.systemd.enable = true;
  # console.earlySetup = lib.mkForce false;
  # boot.consoleLogLevel = 3;
  boot.kernelParams = [
    # "rd.systemd.show_status=auto" "rd.udev.log_level=3" "vt.global_cursor_default=0"
  ];

  # boot.kernelPackages = pkgs.linuxPackages_latest;
  # boot.loader.systemd-boot.enable = true;
  boot.lanzaboote.enable = true;
  boot.lanzaboote.pkiBundle = "/etc/secureboot";
  boot.loader.efi.canTouchEfiVariables = true;

  boot.extraModprobeConfig = ''
    options iwlwifi disable_11ax=Y
  '';

  nix.settings.substituters = [ "https://nixos.tvix.store" ];
  nix.settings.trusted-users = [ "@wheel" ];

  networking.hostName = "framework";
  networking.firewall.allowedTCPPorts = [ 443 ];
  services.xserver.enable = true;
  services.openssh.enable = true;
  services.smartd.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  environment.variables = {
    MOZ_ENABLE_WAYLAND = "1";
  };
  environment.systemPackages = with pkgs; [
    chromium
    cntr
    neovim
    yubioath-flutter
  ];

  users.users.arian = {
    isNormalUser = true;
    createHome = true;
    extraGroups = [
      "wheel"
      "tss"
    ];
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBMaGVuvE+aNyuAu0E9m5scVhmnVgAutNqridbMnc261cHQwecih720LCqDwTgrI3zbMwixBuU422AK0N81DyekQ="
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBGVpzxBOwLIuy/2jjNoec7YfRHtwImf8688srJXaIRiyA4ye6/Ik8lWDTzzB4+V3rfekK0cx7w5gCOrKaqDRvVc="
    ];
  };

  services.fprintd.enable = false;

  programs.chromium.enable = true;

  system.stateVersion = "24.11"; # Did you read the comment?
}
