{ pkgs, lib, ... }: {
  config = {
    # The defaults of nixos are sufficient to skip the kubelet-start phase
    # 
    /*services.kubernetes = {
      kubelet.enable = true;
      apiserverAddress = "apiserver.arianvp.me";
      };*/

    # TODO set sysctl flags

    environment.systemPackages = with pkgs; [ gitMinimal openssh docker utillinux iproute ethtool thin-provisioning-tools iptables socat ];


    virtualisation.docker.enable = true;

    systemd.services.kubeadm = {
      # These paths are needed to convince kubeadm to bootstrap
      path = with pkgs; [ gitMinimal openssh docker utillinux iproute ethtool thin-provisioning-tools iptables socat ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ConditionPathExists = "!/var/lib/kubelet/config.yaml";
        ExecStart = ''
          ${pkgs.kubernetes}/bin/kubeadm init
        '';
      };
    };
    # kubeadm token create --print-join-command  
    # this does what we want

    systemd.services.kubelet = {
      description = "Kubernetes Kubelet Service";
      wantedBy = [ "multi-user.target" ];
      # after = [ "network.target" "docker.service" "kube-apiserver.service" ];

      path = with pkgs; [ gitMinimal openssh docker utillinux iproute ethtool thin-provisioning-tools iptables socat ];

      serviceConfig = {
        StateDirectory = "kubelet";

        # This populates $KUBELET_KUBEADM_ARGS and is provided
        # by kubeadm init and join
        EnvironmentFile = "-/var/lib/kubelet/kubeadm-flags.env";

        Restart = "always";
        StartLimitInterval= 0;
        RestartSec = 10;

        # TODO, we can infer kubelet.conf from the pki  certs. It is fixed, and can live in the nix store.
        # TODO, bootstrap-kubelet.conf is a bit more complicated, I guess,
        # as we need to provide it the bootstrap token..

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

    # points to our Cloud Loadbalancer
   # services.kubernetes.masterAddress = "apiserver.arianvp.me";
    # TODO enable CNI
  };
}
