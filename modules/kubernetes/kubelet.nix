{ pkgs, ... }:
{
  systemd.services.kubelet = {
    serviceConfig = {
      wantedBy = [ "multi-user.target" ];
      Type = "notify";
      # TODO: enable watchdog
      ExecStart = "${pkgs.kubernetes}/bin/kubelet";
    };
  };
}
