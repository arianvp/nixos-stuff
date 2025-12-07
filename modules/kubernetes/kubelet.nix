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

    extraArgs = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra command-line arguments to pass to kubelet";
      example = {
        v = "2";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Set defaults for kubelet configuration
    kubernetes.kubelet.settings = {
      apiVersion = lib.mkDefault "kubelet.config.k8s.io/v1beta1";
      kind = lib.mkDefault "KubeletConfiguration";

      # Server configuration
      enableServer = lib.mkDefault true;
      address = lib.mkDefault "::";
      port = lib.mkDefault 10250;

      # Authentication & Authorization
      # TODO: Change to secure defaults
      authentication = lib.mkDefault {
        anonymous.enabled = true;
        webhook.enabled = false;
      };

      authorization.mode = lib.mkDefault "AlwaysAllow";

      # Cluster configuration
      # cluster.local is not RFC compliant and interferes with our network's mDNS
      clusterDomain = lib.mkDefault "cluster.internal";

      # Runtime configuration
      cgroupDriver = lib.mkDefault "systemd";
      resolvConf = lib.mkDefault "/run/systemd/resolve/resolv.conf";
      containerRuntimeEndpoint = lib.mkDefault "unix:///run/crio/crio.sock";
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
      wantedBy = [ "multi-user.target" ];
      after = [ "crio.service" ];
      requires = [ "crio.service" ];

      serviceConfig = {
        Type = "notify";
        WatchdogSec = "30s";
        StateDirectory = "kubelet";

        ExecStart =
          let
            args = lib.cli.toGNUCommandLineShell { } (
              {
                config = kubeletConfigFile;
                kubeconfig = cfg.kubeconfig;
              }
              // cfg.extraArgs
            );
          in
          "${lib.getExe' cfg.package "kubelet"} ${args}";

        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
