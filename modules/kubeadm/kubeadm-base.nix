{ pkgs, lib, config, ... }:
let
  cfg = config.services.kubeadm.kubelet;
in {
  # TODO conflicts services.kubernetes.kubelet
  imports = [ ../containerd.nix  ];
  options.services.kubeadm.kubelet = {
    enable = lib.mkEnableOption ''
      Enables kubeadm support.  This module is minimal on purpose.  It will
      create a kubelet.service that is compatible with kubeadm and it will
      install all runtime dependencies that kubernetes needs. From there on
      it's up to you to further automate this. The commands kubeadm init and
      kubeadm join should allow you to set up a kubernetes cluster with ease.
    '';
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      # TODO Only used by kubeadm
      pkgs.cri-tools

      # TODO Only used by kube-proxy
      pkgs.conntrack-tools

      # TODO Only used by kube-proxy
      pkgs.iptables

      # Brings kubectl and kubeadm in scope
      # TODO: also brings all the other bs in scope. do we want?
      pkgs.kubernetes
    ];

    # TODO: modeprobe@br_netfilter ?
    boot.kernelModules = [ "br_netfilter" ];

    systemd.services.kubelet = {
      description = "Kubernetes Kubelet Service";
      wantedBy = [ "multi-user.target" ];

      unitConfig = {
        ConditionPathExists = [
          "|/etc/kubernetes/kubelet.conf"
          "|/etc/kubernetes/bootstrap-kubelet.conf"
          "/var/lib/kubelet/config.yaml"
        ];
      };
      serviceConfig = {
        StateDirectory = "kubelet";
        ConfigurationDirectory = "kubernetes";

        # This populates $KUBELET_KUBEADM_ARGS and is provided
        # by kubeadm init and join
        EnvironmentFile = "-/var/lib/kubelet/kubeadm-flags.env";

        Restart = "always";
        StartLimitInterval= 0;
        RestartSec = 10;

        ExecStart = ''
          ${pkgs.kubernetes}/bin/kubelet \
            --kubeconfig=/etc/kubernetes/kubelet.conf \
            --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf \
            --config=/var/lib/kubelet/config.yaml \
            $KUBELET_KUBEADM_ARGS
        '';
      };
    };
  };
}
