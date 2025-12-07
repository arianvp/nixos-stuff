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

  systemd.services.kubelet = {
    after = [ "crio.service" ];
    requires = [ "crio.service" ];
  };

  # Set defaults for kubelet configuration
  kubernetes.kubelet.settings = {
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
}
