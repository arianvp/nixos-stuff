{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.kubernetes.kubelet;
  k8sFormats = import ./formats { inherit lib pkgs; };
  k8sLib = import ./lib.nix { inherit lib; };

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
          authentication = {
            anonymous.enabled = false;
            webhook.enabled = true;
            x509.clientCAFile = "/etc/kubernetes/pki/ca.crt";
          };
          authorization.mode = "Webhook";
          clusterDomain = "cluster.internal";
          containerRuntimeEndpoint = "unix:///run/crio/crio.sock";
        }
      '';
    };

    kubeconfig = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to kubeconfig file for kubelet to authenticate to API server.
        If null, runs kubelet in stand-alone mode.
      '';
      example = "/etc/kubernetes/kubelet.conf";
    };

    args = lib.mkOption {
      type = k8sLib.argsType;
      default = { };
      description = ''
        Command-line arguments to pass to kubelet, for the settings that are not
        part of the configuration file (e.g. node-ip).
      '';
      example = {
        node-ip = "2001:db8::1";
      };
    };
  };

  config = lib.mkIf cfg.enable {

    # We only support cgroups v2 so this is the only driver we support
    kubernetes.kubelet.settings.cgroupDriver = "systemd";

    kubernetes.kubelet.args = {
      config = kubeletConfigFile;
      kubeconfig = cfg.kubeconfig;
    };

    systemd.services.kubelet = {
      description = "Kubernetes node agent";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ pkgs.util-linux ];

      serviceConfig = {
        Type = "notify";
        WatchdogSec = "30s";
        StateDirectory = "kubelet";

        ExecStart = "${lib.getExe' cfg.package "kubelet"} ${k8sLib.toArgs cfg.args}";

        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
