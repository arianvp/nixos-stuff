{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  # Virtualization.framework EFI driver doesnt' seem to support graphics anyway
  boot.consoleLogLevel = 3;
  boot.kernelParams = ["quiet"];
  boot.loader.timeout = 0; 
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.compressor = "cat";
  boot.initrd.systemd.enable = true;
  virtualisation.rosetta.enable = true;
   services.getty.autologinUser = "arian";
  # networking.hostName = "nixos"; # Define your hostname.
  # Pick only one of the below networking options.
  # Set your time zone.
  time.timeZone = "Europe/Amsterdam";
  networking.firewall.enable = false;
  programs.nix-ld.enable = true;
  users.users.arian = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; 
    packages = [
      pkgs.vim
      pkgs.direnv
      pkgs.nixpkgs-fmt
    ];
    openssh.authorizedKeys.keys = [ 
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBMaGVuvE+aNyuAu0E9m5scVhmnVgAutNqridbMnc261cHQwecih720LCqDwTgrI3zbMwixBuU422AK0N81DyekQ= arian@Arians-MacBook-Pro.local"
    ];  
  };

  services.openssh.enable = true;

  environment.systemPackages = [ pkgs.direnv ];
  programs.bash.interactiveShellInit = ''
    eval "$(direnv hook bash)"
  '';

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?

}

