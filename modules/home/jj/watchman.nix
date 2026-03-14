{ pkgs, ... }:
{
  programs.jujutsu.settings.fsmonitor = {
    backend = "watchman";
    watchman.register-snapshot-trigger = true;
  };
  home.packages = [ pkgs.watchman ];
}
