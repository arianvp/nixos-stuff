{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.kubernetes.kube-proxy;
  k8sLib = import ./lib.nix { inherit lib; };
  format = pkgs.formats.yaml { };
in
{
  options.kubernetes.kube-proxy = {
    enable = lib.mkEnableOption "kube-proxy";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.kubernetes;
      description = "Kubernetes package to use";
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
        options = {
          apiVersion = lib.mkOption {
            type = lib.types.str;
            default = "kubeproxy.config.k8s.io/v1alpha1";
            description = "API version";
          };
          kind = lib.mkOption {
            type = lib.types.str;
            default = "KubeProxyConfiguration";
            description = "Resource kind";
          };
          mode = lib.mkOption {
            type = lib.types.enum [
              "iptables"
              "ipvs"
              "nftables"
            ];
            default = "nftables";
            description = "Which proxy mode to use.";
          };
        };
      };
      default = { };
      description = ''
        kube-proxy configuration.
        See https://kubernetes.io/docs/reference/config-api/kube-proxy-config.v1alpha1/
      '';
      example = lib.literalExpression ''
        {
          clientConnection.kubeconfig = "/etc/kubernetes/kube-proxy.conf";
          clusterCIDR = "fd00:10:244::/56";
        }
      '';
    };

    args = lib.mkOption {
      type = k8sLib.argsType;
      default = { };
      description = "Command-line arguments to pass to kube-proxy.";
    };
  };

  config = lib.mkIf cfg.enable {
    kubernetes.kube-proxy.args.config = format.generate "kube-proxy.yaml" cfg.settings;

    systemd.services.kube-proxy = {
      description = "Kubernetes service proxy";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [
        pkgs.nftables
        pkgs.iptables
        pkgs.conntrack-tools
        pkgs.kmod
      ];

      serviceConfig = {
        ExecStart = "${lib.getExe' cfg.package "kube-proxy"} ${k8sLib.toArgs cfg.args}";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
