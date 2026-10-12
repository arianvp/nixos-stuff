{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.kubernetes.kube-scheduler;
  k8sFormats = import ./formats { inherit lib pkgs; };
  k8sLib = import ./lib.nix { inherit lib; };

  schedulerConfigFile = k8sFormats.kubeSchedulerConfiguration.generate "scheduler-config.yaml" cfg.settings;
in
{
  options.kubernetes.kube-scheduler = {
    enable = lib.mkEnableOption "kube-scheduler";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.kubernetes;
      description = "Kubernetes package to use";
    };

    settings = lib.mkOption {
      type = k8sFormats.kubeSchedulerConfiguration.type;
      default = { };
      description = ''
        Kube-scheduler configuration.
        See https://kubernetes.io/docs/reference/config-api/kube-scheduler-config.v1/
      '';
      example = lib.literalExpression ''
        {
          clientConnection.kubeconfig = "/etc/kubernetes/scheduler.conf";
          leaderElection.leaderElect = true;
        }
      '';
    };

    args = lib.mkOption {
      type = k8sLib.argsType;
      default = { };
      description = ''
        Command-line arguments to pass to kube-scheduler, for the settings that
        are not part of the configuration file (e.g. authentication-kubeconfig).
      '';
      example = {
        authentication-kubeconfig = "/etc/kubernetes/scheduler.conf";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    kubernetes.kube-scheduler.args.config = schedulerConfigFile;

    systemd.services.kube-scheduler = {
      description = "Kubernetes scheduler";
      wantedBy = [ "multi-user.target" ];
      after = [ "kube-apiserver.service" ];

      serviceConfig = {
        ExecStart = "${lib.getExe' cfg.package "kube-scheduler"} ${k8sLib.toArgs cfg.args}";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
