{ pkgs, lib, config, ... }: 
let 
  cfg = config.services.kubeadm; 
  path = with pkgs; [
    docker utillinux iproute ethtool iptables socat
  ];
in {
  options.services.kubeadm = {
    enable = lib.mkEnableOption ''
      Enables kubeadm support.  This module is minimal on purpose.  It will
      create a kubelet.service that is compatible with kubeadm and it will
      install all runtime dependencies that kubernetes needs. From there on
      it's up to you to further automate this. The commands kubeadm init and
      kubeadm join should allow you to set up a kubernetes cluster with ease.
    '';
  };
  # TODO:  put --discovery-file in  .well-known/kubeconfig.yaml

  # Got this from https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/#turning-off-public-access-to-the-cluster-info-configmap
  # kubectl -n kube-public get cm cluster-info -o json | jq -r '.data.kubeconfig > /etc/kubernetes/cluster-info.cfg'

  # https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/#file-or-https-based-discovery

  config = lib.mkIf cfg.enable {

    boot.kernelModules = [ "br_netfilter" ];

    boot.kernel.sysctl = {
      # TODO IPV6/DualStack
      "net.ipv4.ip_forward" = 1;  
      "net.bridge.bridge-nf-call-iptables" = 1;
    };


    environment.systemPackages = [ pkgs.kubernetes ] ++ path;

    virtualisation.docker.enable = true;

    systemd.services.kubelet = {
      description = "Kubernetes Kubelet Service";
      wantedBy = [ "multi-user.target" ];

      path = with pkgs; [ openssh docker utillinux iproute ethtool thin-provisioning-tools iptables socat ];

      serviceConfig = {
        StateDirectory = "kubelet";

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
            --cni-bin-dir=${pkgs.cni}/bin \
            $KUBELET_KUBEADM_ARGS
        '';
      };
    };
  };
}
