{ pkgs, ... }:
let
  startAt = "10:39";
in
{
  systemd.timers.TASK_mytask = {
    wantedBy = [ "timers.target" ];
    enable = true;
    timerConfig = {
      OnCalendar = startAt;
      AccuracySec = "10ms";
      RandomizedDelaySec = 10;
    };
  };

  systemd.services.TASK_mytask = {
    enable = true;
    description = "oneOffTask: ${toString startAt}";
    path = [ pkgs.coreutils ];
    serviceConfig = {
      ExecStart = "${pkgs.coreutils}/bin/sleep 10";
    };
    stopIfChanged = false;
    restartIfChanged = false;
    reloadIfChanged = false;
  };
}
