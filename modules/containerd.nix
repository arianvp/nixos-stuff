{ lib, pkgs, config, utils, ... }:
let
  cfg = config.virtualisation.containerd;

  # TODO: Make cni-plugins configurable? e.g. to use calico-ipam
  # TODO: Not use /etc/cni/net.d if we can get away without it? I think many DaemonSets on k8s depend on its existence
  configFile = pkgs.writeText "config.toml" ''
    version = 2
    [plugins."io.containerd.grpc.v1.cri".cni]
      bin_dir = "${pkgs.cni-plugins}/bin"
      conf_dir = "/etc/cni/net.d"
    [plugins."io.containerd.grpc.v1.cri".containerd]
      snapshotter = "btrfs"
  '';
in
{
  options.virtualisation.containerd = {
    enable = lib.mkEnableOption "containerd";
  };
  config = lib.mkIf cfg.enable {
    environment.etc = {
      "cni/net.d/99-loopback.conf".text = ''
        {
            "cniVersion": "0.3.1",
            "type": "loopback"
        }
      '';
      /*
      TODO: Make a SLAAC plugin
      "cni/net.d/5-bridge.conflist".text = ''
        {
          "name": "net",
          "cniVersion": "0.3.1",
          "plugins": [
            {
              "type": "macvlan",
              "master": "enp35s0",
              "ipam": { }
            },
            {
              "type": "portmap",
              "snat": true,
              "capabilities": {
                "portMappings": true
              }
            }
          ]
        }
      ''; */
      "cni/net.d/5-bridge.conflist".text = ''
        {
          "name": "net",
          "cniVersion": "0.3.1",
          "plugins": [
            {
              "type": "bridge",
              "bridge": "cni0",
              "isGateway": true,
              "ipMasq": true,
              "hairpinMode": true,
              "ipam": {
                "type": "host-local",
                "routes": [
                  {
                    "dst": "0.0.0.0/0"
                  }
                ],
                "ranges": [
                  [
                    {
                      "subnet": "10.85.0.0/16"
                    }
                  ]
                ]
              }
            },
            {
              "type": "portmap",
              "snat": true,
              "capabilities": {
                "portMappings": true
              }
            }
          ]
        }
      '';
    };
    boot.kernelModules = [ "overlay" ];
    systemd.services.containerd = {
      wantedBy = [ "multi-user.target" ];

      # TODO: wrapProgram
      path = [
        pkgs.iptables
        pkgs.runc
      ];
      serviceConfig = {
        ExecStart = "${pkgs.containerd}/bin/containerd --config ${configFile} ";
        Delegate = "yes";
        KillMode = "process";
        Restart = "always";
        RestartSec = "5";
        LimitNPROC = "infinity";
        LimitCORE = "infinity";
        LimitNOFILE = "infinity";
        TasksMax = "infinity";
        OOMScoreAdjust = "-999";
      };
    };
  };
}
