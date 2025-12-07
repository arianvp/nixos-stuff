{ pkgs, ... }:

{
  # TODO: Configure with config file and best practises
  # TODO: not localhost
  systemd.services.etcd = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "notify";
      StateDirectory = "etcd";
      ExecStart = "${pkgs.etcd}/bin/etcd --name %H --data-dir $STATE_DIRECTORY";
    };
  };
}
