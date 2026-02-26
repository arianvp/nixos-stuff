{ pkgs, ... }:
{

  programs.niri.enable = true;
  # programs.waybar.enable = true;

  # Required services for noctalia
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  fonts.packages = with pkgs; [ font-awesome ];
}

