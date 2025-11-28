{
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./spire.nix
    ./prometheus.nix
    ../../modules/ssh.nix
    ../../modules/yggdrasil.nix
    ../../modules/tailscale.nix
    ../../modules/prometheus.nix
    ../../modules/alertmanager.nix
    # ../../websites/nixos.sh
  ];

  services.yggdrasil.persistentKeys = true;
  security.tpm2.enable = true;

  # NOTE: temporary measure until we remove the need for sudo
  # We just mint root user certs instead
  security.sudo.wheelNeedsPassword = false;

  networking.hostName = "altra";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.timeout = 20;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;
  services.getty.autologinUser = "arian";
  time.timeZone = "Europe/Amsterdam";
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    80
    443
    22
  ];

  services.nginx.enable = true;

  users.groups.nix-trusted-users = { };
  users.users.m = {
    extraGroups = [ "nix-trusted-users" ];
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC/HMAT/nOa8F5LrFebnG7wk1o/K0Rx1HdDoFYxvLSef root@p4"
    ];
  };
  users.users.flokli = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "nix-trusted-users"
    ];
  };
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  environment.systemPackages = [
    pkgs.kitty.terminfo
  ];
  programs.zsh.enable = true;

  system.name = "altra";

  nix.settings.trusted-users = [ "@wheel" ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "fetch-closure"
  ];
  nix.settings.system-features = [
    "nixos-test"
    "benchmark"
    "big-parallel"
    "kvm"
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?A
}
