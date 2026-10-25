{ pkgs, ... }:
{
  programs.niri.enable = true;

  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    systemd.target = "niri.service";
    recommendedServices.enable = true;
  };

  fonts.packages = with pkgs; [ font-awesome ];
}
