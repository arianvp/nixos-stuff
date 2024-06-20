{ config, lib, pkgs, inputs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  # Virtualization.framework EFI driver doesnt' seem to support graphics anyway
  boot.consoleLogLevel = 3;
  boot.kernelParams = [ "debug1"  "console=ttyS0" ];
  boot.loader.timeout = 20;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.compressor = "cat";
  boot.initrd.systemd.enable = false;
  # system.etc.overlay.enable = true;
  virtualisation.rosetta.enable = true;
  virtualisation.podman.enable = true;
  services.getty.autologinUser = "arian";
  # networking.hostName = "nixos"; # Define your hostname.
  # Pick only one of the below networking options.
  # Set your time zone.
  # See https://github.com/NixOS/nixpkgs/issues/311125 
  # time.timeZone = "Europe/Amsterdam";
  networking.firewall.enable = false;
  programs.nix-ld.enable = true;
  systemd.targets.network-online.wantedBy = lib.mkForce [ ];
  users.users.arian = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = [
      pkgs.vim
      pkgs.git
      pkgs.direnv
      pkgs.bpftrace
    ];
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBMaGVuvE+aNyuAu0E9m5scVhmnVgAutNqridbMnc261cHQwecih720LCqDwTgrI3zbMwixBuU422AK0N81DyekQ= arian@Arians-MacBook-Pro.local"
    ];
  };

  services.openssh.enable = true;
  services.openssh.startWhenNeeded = true;

  # Systemd conveniently ships with this service that will check if no services failed
  # https://www.freedesktop.org/software/systemd/man/systemd-boot-check-no-failures.service.html
  # This is part of https://systemd.io/AUTOMATIC_BOOT_ASSESSMENT/
  systemd.additionalUpstreamSystemUnits = [
    "boot-complete.target"
    "systemd-boot-check-no-failures.service"
  ];

  # TODO Fix upstream
  # systemd.targets.boot-complete.requires = [ "systemd-boot-check-no-failures.service" ];



  environment.systemPackages = [ pkgs.direnv ];
  programs.zsh.enable = true;
  programs.bash.interactiveShellInit = ''
    eval "$(direnv hook bash)"
  '';

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?A


}

