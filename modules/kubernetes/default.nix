{ lib, config, ... }:
let
  cfg = config.kubernetes;

  # The network address of a CIDR plus one, which the API server allocates to
  # the kubernetes Service
  firstAddress =
    cidr:
    if lib.hasInfix ":" cidr then
      let
        groups = lib.splitString ":" (lib.network.ipv6.fromString cidr).address;
      in
      lib.concatStringsSep ":" (
        lib.init groups ++ [ (lib.toLower (lib.toHexString (lib.fromHexString (lib.last groups) + 1))) ]
      )
    else
      let
        octets = lib.splitString "." (lib.head (lib.splitString "/" cidr));
      in
      lib.concatStringsSep "." (lib.init octets ++ [ (toString (lib.toInt (lib.last octets) + 1)) ]);
in
{
  imports = [
    ./etcd.nix
    ./kube-apiserver.nix
    ./kube-jwt-signer.nix
    ./kube-scheduler.nix
    ./kube-controller-manager.nix
    ./kubelet.nix
    ./kube-proxy.nix
    ./cluster-dns.nix
    ./crio.nix
    ./cni.nix
    ./images.nix
    ./kubeconfig.nix
    ./addons.nix
    ./spire.nix
  ];

  options.kubernetes = {
    clusterName = lib.mkOption {
      type = lib.types.str;
      default = "kubernetes";
      description = "Name of the cluster.";
    };

    clusterDomain = lib.mkOption {
      type = lib.types.str;
      # cluster.local is not RFC compliant and interferes with our network's mDNS
      default = "cluster.internal";
      description = "DNS domain of the cluster.";
    };

    serviceCIDR = lib.mkOption {
      type = lib.types.str;
      description = "IP range Services get their cluster IPs from.";
      example = "fd00:10:96::/112";
    };

    apiServerServiceIP = lib.mkOption {
      type = lib.types.str;
      default = firstAddress cfg.serviceCIDR;
      defaultText = lib.literalMD "the first address in {option}`kubernetes.serviceCIDR`";
      description = "Cluster IP of the kubernetes Service, which pods reach the API server by.";
    };
  };

  config.kubernetes = {
    kubelet.settings.clusterDomain = lib.mkDefault cfg.clusterDomain;
    kube-apiserver.args.service-cluster-ip-range = lib.mkDefault cfg.serviceCIDR;
  };
}
