{ pkgs, lib, config, ... }: let cfg = config.services.kubeadm; in {
  options.services.kubeadm = {
    enable = lib.mkEnableOption "kubeadm";
    role = lib.mkOption {
      type = lib.types.enum ["master" "worker" ];
    };
    apiserverAddress = lib.mkOption {
      type = lib.types.str;
      description = ''
        The address on which we can reach the masters. Could be loadbalancer
      '';
    };
    tlsBootstrapToken = lib.mkOption {
      type = lib.types.str;
      description = ''
        The master will print this to stdout after being set up. 
      '';
    };


    discoveryFile = lib.mkOption {
      type = lib.types.str;
      description = ''
        The HTTP URL where we can find the cluster info
      '';
    };

  };
  # TODO:  put --discovery-file in  .well-known/kubeconfig.yaml

  # Got this from https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/#turning-off-public-access-to-the-cluster-info-configmap
  # kubectl -n kube-public get cm cluster-info -o json | jq -r '.data.kubeconfig > /etc/kubernetes/cluster-info.cfg'

  # https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/#file-or-https-based-discovery

  config = lib.mkIf cfg.enable {

    boot.kernelModules = [ "br_netfilter" ];

    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.bridge.bridge-nf-call-iptables" = 1;
    };


    environment.systemPackages = with pkgs; [ 
      gitMinimal
      openssh 
      docker 
      utillinux 
      iproute 
      ethtool 
      thin-provisioning-tools 
      iptables 
      socat 
    ];


    virtualisation.docker.enable = true;

    systemd.services.kubeadm = {
      wantedBy = [ "multi-user.target" ];
      after = [ "kubelet.service" ];

      # These paths are needed to convince kubeadm to bootstrap
      path = with pkgs; [ kubernetes jq gitMinimal openssh docker utillinux iproute ethtool thin-provisioning-tools iptables socat ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Makes sure that its only started once, during bootstrap
        ConditionPathExists = "!/var/lib/kubelet/config.yaml";
        ExecStart = {
          master = "${pkgs.kubernetes}/bin/kubeadm init --token ${cfg.tlsBootstrapToken}";
          worker = "${pkgs.kubernetes}/bin/kubeadm join ${cfg.apiserverAddress} --tls-bootstrap-token ${cfg.tlsBootstrapToken} --discovery-file ${cfg.discoveryFile}";
        }.${cfg.role};
      } // lib.mkIf (cfg.role == "master") {
        requires = [ "cni-init.service" ];
        before = [ "cni-init.service" ];
        postStart = ''
          kubectl -n kube-public get cm cluster-info -o json | jq -r '.data.kubeconfig > /etc/kubernetes/cluster-info.cfg'
          chmod a+r /etc/kubernetes/cluster-info.cfg
        '';
      };
    };

    systemd.services.cni-init = {
      path = with pkgs; [ kubernetes ];
      script = ''
        echo "Hello, this will do something later" 
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    systemd.services.kubelet = {
      description = "Kubernetes Kubelet Service";
      wantedBy = [ "multi-user.target" ];

      path = with pkgs; [ gitMinimal openssh docker utillinux iproute ethtool thin-provisioning-tools iptables socat ];

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
    # TODO enable CNI
  };
}
