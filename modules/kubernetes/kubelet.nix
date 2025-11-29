{ pkgs, ... }:
{
  systemd.services.kubelet = {
    serviceConfig = {
      Type = "exec";
      ExecStart = "${pkgs.kubernetes}/bin/kubelet";
    };
  };
}
