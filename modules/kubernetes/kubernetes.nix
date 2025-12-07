{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    ./etcd.nix
    ./kube-apiserver.nix
    ./kube-scheduler.nix
    ./kube-controller-manager.nix
    ./kubelet.nix
    ./crio.nix
    ./kubeconfig.nix
  ];

  kubernetes.kube-apiserver = {
    enable = true;
    args = {
      # etcd
      etcd-servers = [ "http://127.0.0.1:2379" ];

      # Service account configuration
      service-account-issuer = "https://spire.nixos.sh";
      # TODO: delegate signing to SPIRE: https://github.com/kubernetes/enhancements/tree/master/keps/sig-auth/740-service-account-external-signing
      # service-account-signing-endpoint = "/run/signing.sock";

      service-account-key-file = "/var/run/kubernetes/sa.key";
      service-account-signing-key-file = "/var/run/kubernetes/sa.key";

      # The default; but conceptually wrong when the issuer is external.
      # TODO: change to the cluster api server address in the future
      # api-audiences = [ "https://spire.nixos.sh" ];

      # Bind address
      bind-address = lib.mkDefault "::";
      # advertise-address is auto-detected

      # Service cluster IP range (must match bind-address IP family)
      # Using IPv6 since bind-address defaults to "::"
      service-cluster-ip-range = lib.mkDefault "fd00:10:96::/112";

      # TODO: Authentication
      # TODO: Authorization
    };
  };

  systemd.services.kube-apiserver.serviceConfig = {
    # TODO: Key persistence or out-source to SPIRE
    ExecStartPre = pkgs.writeShellScript "generate-sa-key" ''
      ${pkgs.openssl}/bin/openssl ecparam -genkey -name prime256v1 -out /var/run/kubernetes/sa.key
      ${pkgs.openssl}/bin/openssl ec -in /var/run/kubernetes/sa.key -pubout -out /var/run/kubernetes/sa.pub
    '';
  };

  # Set defaults for kubelet configuration
  kubernetes.kubelet = {
    enable = true;
    kubeconfig = "${config.kubernetes.kubeconfigs.kubelet.file}";
    settings = {
      enableServer = true;
      address = "::";
      port = 10250;

      # Authentication & Authorization
      # TODO: Change to secure defaults
      authentication = {
        anonymous.enabled = true;
        webhook.enabled = false;
      };

      authorization.mode = "AlwaysAllow";

      # Cluster configuration
      # cluster.local is not RFC compliant and interferes with our network's mDNS
      clusterDomain = "cluster.internal";

      # Runtime configuration
      resolvConf = "/run/systemd/resolve/resolv.conf";
      containerRuntimeEndpoint = "unix:///run/crio/crio.sock";

      staticPodPath = "/etc/kubernetes/manifests";

    };
  };

  # Generate default kubeconfig using the kubeconfig module
  kubernetes.kubeconfigs.kubelet = {
    clusterMap.kubernetes = {
      server = "https://[::1]:6443";
      # TODO: Add CA certificate verification
      insecure-skip-tls-verify = true;
    };

    userMap.kubelet.exec = {
      command = "k8s-spiffe-workload-jwt-exec-auth";
      interactiveMode = "Never";
    };

    contextMap.kubelet = {
      cluster = "kubernetes";
      user = "kubelet";
    };

    settings.current-context = "kubelet";
  };


  systemd.services.kubelet = {
    after = [ "crio.service" ];
    requires = [ "crio.service" ];
  };

  environment.etc."kubernetes/manifests/nginx.yaml".text = lib.generators.toYAML {} {
    apiVersion = "v1";
    kind = "Pod";
    metadata = {
      name = "nginx";
      namespace = "default";
      labels = {
        app = "nginx";
      };
    };
    spec = {
      containers = [{
        name = "nginx";
        image = "nginx:latest";
        ports = [{
          containerPort = 80;
          name = "http";
          protocol = "TCP";
        }];
      }];
    };
  };
}
