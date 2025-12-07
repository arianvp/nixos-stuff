{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.kubernetes.kubelet;
  k8sFormats = import ./formats { inherit lib pkgs; };

  kubeletConfigFile = k8sFormats.kubeletConfiguration.generate "kubelet-config.yaml" cfg.settings;

in
{
  options.kubernetes.kubelet = {
    enable = lib.mkEnableOption "kubelet";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.kubernetes;
      description = "Kubernetes package to use";
    };

    settings = lib.mkOption {
      type = k8sFormats.kubeletConfiguration.type;
      default = { };
      description = ''
        Kubelet configuration.
        See https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/
      '';
      example = lib.literalExpression ''
        {
          apiVersion = "kubelet.config.k8s.io/v1beta1";
          kind = "KubeletConfiguration";

          enableServer = true;
          address = "::";
          port = 10250;

          authentication = {
            anonymous.enabled = false;
            webhook = {
              enabled = true;
              cacheTTL = "2m0s";
            };
            x509.clientCAFile = "/etc/kubernetes/pki/ca.crt";
          };

          authorization = {
            mode = "Webhook";
          };

          clusterDomain = "cluster.internal";
          cgroupDriver = "systemd";
          containerRuntimeEndpoint = "unix:///run/crio/crio.sock";
        }
      '';
    };

    kubeconfig = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "/etc/kubernetes/kubelet.conf";
      description = ''
        Path to kubeconfig file for kubelet to authenticate to API server.
        If null, runes kubelet in stand-alone mode.
      '';
      example = "/etc/kubernetes/kubelet.conf";
    };
  };

  config = lib.mkIf cfg.enable {

    # We only support cgroups v2 so this is the only driver we support
    kubernetes.kubelet.settings.cgroupDriver = "systemd";

    systemd.services.kubelet = {
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "notify";
        WatchdogSec = "30s";
        StateDirectory = "kubelet";

        ExecStart =
          let
            args = lib.cli.toGNUCommandLineShell { } {
              config = kubeletConfigFile;
              kubeconfig = cfg.kubeconfig;
            };
          in
          "${lib.getExe' cfg.package "kubelet"} ${args}";

        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
