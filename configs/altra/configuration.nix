{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./spire.nix
    ./prometheus.nix
    ../../modules/yggdrasil.nix
    ../../modules/tailscale.nix
    ../../modules/prometheus.nix
    ../../modules/alertmanager.nix
    # ../../websites/nixos.sh
  ];

  services.yggdrasil.persistentKeys = true;
  security.tpm2.enable = true;

  networking.hostName = "matthew";

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.timeout = 20;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;
  services.getty.autologinUser = "arian";
  time.timeZone = "Europe/Amsterdam";
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    443
    22
  ];

  users.groups.nix-trusted-users = { };
  users.users.picnoir = {
    extraGroups = [ "nix-trusted-users" ];
    isNormalUser = true;
    openssh.authorizedKeys.keyFiles = [
      (pkgs.fetchurl {
        url = "https://codeberg.org/picnoir.keys";
        sha256 = "sha256-bS0BVP0K0KZ3vHyYcHpfRzOVQeO/7XlKWK+UYj1j6Fo=";
      })
    ];
  };
  users.users.raito = {
    extraGroups = [ "wheel" ];
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKiXXYkhRh+s7ixZ8rvG8ntIqd6FELQ9hh7HoaHQJRPU Thorkell"
    ];
  };
  users.users.m = {
    extraGroups = [ "nix-trusted-users" ];
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC/HMAT/nOa8F5LrFebnG7wk1o/K0Rx1HdDoFYxvLSef root@p4"
    ];
  };
  users.users.butz = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keyFiles = [
      (pkgs.fetchurl {
        url = "https://github.com/willibutz.keys";
        sha256 = "sha256-+VU7unfOQ2wxKSXlIW351wmpBHqwgFf1nct7A0jVlaI=";
      })
    ];
  };
  users.users.flokli = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = [
      pkgs.vim
      pkgs.git
      pkgs.btop
      pkgs.tmux
      pkgs.nix-output-monitor
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPTVTXOutUZZjXLB0lUSgeKcSY/8mxKkC0ingGK1whD2"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE6a15p9HLSrawsMTd2UQGAiM7r7VdyrfSRyzwRYTgWT"
    ];
  };

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  environment.systemPackages = [
    pkgs.kitty.terminfo
  ];
  programs.zsh.enable = true;

  system.name = "matthew";

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
