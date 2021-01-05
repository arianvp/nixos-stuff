
{ pkgs, lib, config, ... }:
let
  cfg = config.cluster.kubernetes;
  ip = "192.168.0.23";
in
{
  # TODO conflicts services.kubernetes.kubelet
  imports = [ ./containerd.nix ];
  options.cluster.kubernetes = {
    enable = lib.mkEnableOption ''
      Set up a single-node conformant and secure kubernetes cluster
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

    # TODO: Is this needed per se?
    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

    virtualisation.containerd.enable = true;

    systemd.services.kubeadm-init = {
      wants = [ "etcd.service" "kube-scheduler.service" "kube-apiserver.service" "kube-controller-manager.service" ];
      before = [ "etcd.service" "kube-scheduler.service" "kube-apiserver.service" "kube-controller-manager.service" ];
      script = ''
        ${pkgs.kubernetes}/bin/kubeadm init phase certs all
        ${pkgs.kubernetes}/bin/kubeadm init phase kubeconfig controller-manager
        ${pkgs.kubernetes}/bin/kubeadm init phase kubeconfig scheduler
        ${pkgs.kubernetes}/bin/kubeadm init phase kubeconfig admin
      '';
      serviceConfig = {
        Type = "oneshot";
        ConfigurationDirectory = "kubernetes";
      };
    };

    systemd.services.etcd = {
      serviceConfig = {
        Type = "notify";
        Restart = "always";
        RestartSec = "10s";
        LimitNOFILE = 40000;
        StateDirectory = "etcd";
        ExecStart = ''
          ${pkgs.etcd}/bin/etcd \
          --advertise-client-urls=https://192.168.0.23:2379 \
          --cert-file=/etc/kubernetes/pki/etcd/server.crt \
          --client-cert-auth=true \
          --data-dir=/var/lib/etcd \
          --initial-advertise-peer-urls=https://192.168.0.23:2380 \
          --initial-cluster=ryzen=https://192.168.0.23:2380 \
          --key-file=/etc/kubernetes/pki/etcd/server.key \
          --listen-client-urls=https://127.0.0.1:2379,https://192.168.0.23:2379 \
          --listen-metrics-urls=http://127.0.0.1:2381 \
          --listen-peer-urls=https://192.168.0.23:2380 \
          --name=ryzen \
          --peer-cert-file=/etc/kubernetes/pki/etcd/peer.crt \
          --peer-client-cert-auth=true \
          --peer-key-file=/etc/kubernetes/pki/etcd/peer.key \
          --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt \
          --snapshot-count=10000 \
          --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
        '';
      };
    };

    systemd.services.kube-apiserver = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Restart = "always";
        RestartSec = "10s";
        ExecStart = ''
          ${pkgs.kubernetes}/bin/kube-apiserver \
          --advertise-address=${ip} \
          --allow-privileged=true \
          --authorization-mode=Node,RBAC \
          --client-ca-file=/etc/kubernetes/pki/ca.crt \
          --enable-admission-plugins=NodeRestriction \
          --enable-bootstrap-token-auth=true \
          --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt \
          --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt \
          --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key \
          --etcd-servers=https://127.0.0.1:2379 \
          --insecure-port=0 \
          --kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt \
          --kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key \
          --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname \
          --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt \
          --proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key \
          --requestheader-allowed-names=front-proxy-client \
          --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt \
          --requestheader-extra-headers-prefix=X-Remote-Extra- \
          --requestheader-group-headers=X-Remote-Group \
          --requestheader-username-headers=X-Remote-User \
          --secure-port=6443 \
          --service-account-key-file=/etc/kubernetes/pki/sa.pub \
          --service-cluster-ip-range=10.96.0.0/12 \
          --tls-cert-file=/etc/kubernetes/pki/apiserver.crt \
          --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
        '';
      };
    };
    /*systemd.paths.kube-controller-manager = {
      wantedBy = [ "paths.target" ];
      pathConfig.PathExists = [ "/etc/kubernetes/controller-manager.conf" ];
    };*/
    systemd.services.kube-controller-manager = {
      serviceConfig = {
        Restart = "always";
        RestartSec = "10s";
        ExecStart = ''
          ${pkgs.kubernetes}/bin/kube-controller-manager \
          --authentication-kubeconfig=/etc/kubernetes/controller-manager.conf \
          --authorization-kubeconfig=/etc/kubernetes/controller-manager.conf \
          --bind-address=127.0.0.1 \
          --client-ca-file=/etc/kubernetes/pki/ca.crt \
          --cluster-name=kubernetes \
          --cluster-signing-cert-file=/etc/kubernetes/pki/ca.crt \
          --cluster-signing-key-file=/etc/kubernetes/pki/ca.key \
          --controllers=*,bootstrapsigner,tokencleaner \
          --kubeconfig=/etc/kubernetes/controller-manager.conf \
          --leader-elect=true \
          --port=0 \
          --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt \
          --root-ca-file=/etc/kubernetes/pki/ca.crt \
          --service-account-private-key-file=/etc/kubernetes/pki/sa.key \
          --use-service-account-credentials=true
        '';
      };
    };
    /*systemd.paths.kube-scheduler = {
      wantedBy = [ "paths.target" ];
      pathConfig.PathExists = [ "/etc/kubernetes/scheduler.conf" ];
    };*/
    systemd.services.kube-scheduler = {
      unitConfig.ConditionPathExists = [ "/etc/kubernetes/scheduler.conf" ];
      serviceConfig = {
        Restart = "always";
        RestartSec = "10s";
        ExecStart = ''
          ${pkgs.kubernetes}/bin/kube-scheduler \
          --authentication-kubeconfig=/etc/kubernetes/scheduler.conf \
          --authorization-kubeconfig=/etc/kubernetes/scheduler.conf \
          --bind-address=127.0.0.1 \
          --kubeconfig=/etc/kubernetes/scheduler.conf \
          --leader-elect=true \
          --port=0
        '';
      };
    };

    /*systemd.paths.kubelet = {
      wantedBy = [ "paths.target" ];
      pathConfig.PathExists = [
        "/etc/kubernetes/kubelet.conf"
        "/etc/kubernetes/bootstrap-kubelet.conf"
      ];
    };*/

    systemd.services.kube-proxy = {
    };
    systemd.services.kubelet =
      let config = pkgs.writeText "config.yaml" ''
        apiVersion: kubelet.config.k8s.io/v1beta1
        authentication:
          anonymous:
            enabled: false
          webhook:
            cacheTTL: 0s
            enabled: true
          x509:
            clientCAFile: /etc/kubernetes/pki/ca.crt
        authorization:
          mode: Webhook
          webhook:
            cacheAuthorizedTTL: 0s
            cacheUnauthorizedTTL: 0s
        clusterDNS:
        - 10.96.0.10
        clusterDomain: cluster.local
        cpuManagerReconcilePeriod: 0s
        evictionPressureTransitionPeriod: 0s
        fileCheckFrequency: 0s
        healthzBindAddress: 127.0.0.1
        healthzPort: 10248
        httpCheckFrequency: 0s
        imageMinimumGCAge: 0s
        kind: KubeletConfiguration
        logging: {}
        nodeStatusReportFrequency: 0s
        nodeStatusUpdateFrequency: 0s
        rotateCertificates: true
        runtimeRequestTimeout: 0s
        streamingConnectionIdleTimeout: 0s
        syncFrequency: 0s
        volumeStatsAggPeriod: 0s
      ''; in
      {

        path = [
          # NOTE: iptables.go:556] Could not set up iptables canary mangle/KUBE-KUBELET-CANARY: error creating chain "KUBE-KUBELET-CANARY": executable file not found in $PATH:
          # NOTE: kubelet_network_linux.go:62] Failed to ensure that nat chain KUBE-MARK-DROP exists: error creating chain "KUBE-MARK-DROP": executable file not found in $PATH:
          pkgs.iptables

          # NOTE: Needed for mounting
          pkgs.utillinux
        ];

        requires = [ "containerd.service" ];
        after = [ "containerd.service" ];

        serviceConfig = {
          StateDirectory = "kubelet";
          ConfigurationDirectory = [ "kubernetes" ];

          Restart = "always";
          RestartSec = "10s";

          ExecStart = ''
            ${pkgs.kubernetes}/bin/kubelet \
              --kubeconfig=/etc/kubernetes/kubelet.conf \
              --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf \
              --container-runtime=remote \
              --container-runtime-endpoint=/run/containerd/containerd.sock \
              --config=${config}
          '';
        };
      };
  };
}
