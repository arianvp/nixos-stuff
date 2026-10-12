{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.kubernetes.kube-controller-manager;
  k8sLib = import ./lib.nix { inherit lib; };
in
{
  options.kubernetes.kube-controller-manager = {
    enable = lib.mkEnableOption "kube-controller-manager";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.kubernetes;
      description = "Kubernetes package to use";
    };

    args = lib.mkOption {
      type = k8sLib.argsType;
      default = { };
      description = ''
        Command-line arguments to pass to kube-controller-manager.

        kube-controller-manager has no configuration file; all configuration is
        done with flags.

        See https://kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/
      '';
      example = lib.literalExpression ''
        {
          kubeconfig = "/etc/kubernetes/controller-manager.conf";
          leader-elect = true;
          cluster-name = "kubernetes";
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    kubernetes.kube-controller-manager.args = {
      leader-elect = lib.mkDefault true;
      cluster-name = lib.mkDefault "kubernetes";
    };

    systemd.services.kube-controller-manager = {
      description = "Kubernetes controller manager";
      wantedBy = [ "multi-user.target" ];
      after = [ "kube-apiserver.service" ];

      serviceConfig = {
        ExecStart = "${lib.getExe' cfg.package "kube-controller-manager"} ${k8sLib.toArgs cfg.args}";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
