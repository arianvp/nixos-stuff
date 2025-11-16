{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./pcrlock.nix
    ./audit.nix
    ../../modules/vmspawn.nix
    ../../modules/yggdrasil.nix
    ../../modules/tpm2.nix
    ../../modules/ssh-keys.nix
    ./rice.nix
    ./silent-boot.nix
  ];

  services.fwupd.enable = true;

  fileSystems = {
    "/tmp" = {
      device = "tmpfs";
      fsType = "tmpfs";
      # options = [ "nosuid" "nodev" "size=4G" ];
    };
  };

  services.tailscale.enable = true;
  programs.mtr.enable = true;




  boot.initrd.systemd.enable = true;
  # console.earlySetup = lib.mkForce false;
  # boot.consoleLogLevel = 3;
  boot.kernelParams = [
    # "rd.systemd.show_status=auto" "rd.udev.log_level=3" "vt.global_cursor_default=0"
  ];

  # boot.kernelPackages = pkgs.linuxPackages_latest;
  # boot.loader.systemd-boot.enable = true;
  boot.lanzaboote.enable = true;
  boot.lanzaboote.pkiBundle = "/var/lib/sbctl";
  boot.loader.efi.canTouchEfiVariables = true;

  boot.extraModprobeConfig = ''
    options iwlwifi disable_11ax=Y
  '';

  networking.hostName = "framework";
  networking.firewall.enable = true;
  services.openssh.enable = true;
  services.smartd.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  environment.variables = {
    MOZ_ENABLE_WAYLAND = "1";
  };
  environment.systemPackages = with pkgs; [
    chromium
    cntr
    neovim
    yubioath-flutter
    # Wait until it builds
    # zed-editor
    nix-output-monitor
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

  system.stateVersion = "25.05"; # Did you read the comment?
}
