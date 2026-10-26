{ pkgs, ... }:
{
  programs.niri.enable = true;

  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    systemd.target = "niri.service";
    recommendedServices.enable = true;
  };

  # Don't let a background system update restart what draws the bar and the
  # lock screen. If the session is locked at the time the locker goes with it,
  # and niri is left holding the session locked with no locker on screen.
  # Tradeoff: the running shell stays on the old version until logout.
  systemd.user.services.noctalia.restartIfChanged = false;

  fonts.packages = with pkgs; [ font-awesome ];
}
