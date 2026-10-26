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

  # noctalia only talks to an app over D-Bus once something else already owns
  # the name, so ghostty's shipped unit never gets activated and the primary
  # ends up a child of the launcher. Start the unit with the session so it owns
  # com.mitchellh.ghostty first; launches then hand off to it.
  home-manager.users.arian.xdg.configFile."systemd/user/graphical-session.target.wants/app-com.mitchellh.ghostty.service".source =
    "${pkgs.ghostty}/share/systemd/user/app-com.mitchellh.ghostty.service";

  fonts.packages = with pkgs; [ font-awesome ];
}
