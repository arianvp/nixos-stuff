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
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.timeout = 20;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;
  services.getty.autologinUser = "arian";
  time.timeZone = "Europe/Amsterdam";
  networking.firewall.enable = false;
  users.users.arian = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = [
      pkgs.vim
      pkgs.git
      pkgs.direnv
      pkgs.btop
      pkgs.tmux
      pkgs.nix-output-monitor
    ];
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBMaGVuvE+aNyuAu0E9m5scVhmnVgAutNqridbMnc261cHQwecih720LCqDwTgrI3zbMwixBuU422AK0N81DyekQ= arian@Arians-MacBook-Pro.local"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHdERauixCGEk0oxLB+725k2M3McKHM0hjOjOWS+Dxdf arian@Mac"
    ];
  };

  services.openssh.enable = true;

  environment.systemPackages = [ pkgs.direnv ];
  programs.zsh.enable = true;
  programs.bash.interactiveShellInit = ''
    eval "$(direnv hook bash)"
  '';

  system.name = "altra";

  nix.settings.trusted-users = [ "@wheel" ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "fetch-closure"
  ];

  services.tailscale.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?A
}
