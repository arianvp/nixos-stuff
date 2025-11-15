{ pkgs, ... }:
{

  programs.niri.enable = true;
  # programs.waybar.enable = true;

  fonts.packages = with pkgs; [ font-awesome ];

  environment.systemPackages = with pkgs; [
    waybar
    fuzzel
    alacritty
    swaylock
  ];
}
