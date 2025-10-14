{ pkgs, ... }:
{

  programs.niri.enable = true;
  programs.waybar.enable = true;

  environment.systemPackages = with pkgs; [
    fuzzel
    alacritty
    swaylock
  ];
}
