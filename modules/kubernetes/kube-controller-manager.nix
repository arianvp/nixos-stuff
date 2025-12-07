{ pkgs, lib, config, ... }:

let
  cfg = config.kubernetes.kube-controller-manager;
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
      type = lib.types.attrsOf (lib.types.oneOf [ lib.types.str lib.types.int lib.types.bool ]);
      default = {};
      description = ''
        Command-line arguments to pass to kube-controller-manager.
        
        NOTE: kube-controller-manager does NOT support --config flag.
        All configuration must be done via command-line flags.
        
        See https://kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/
      '';
      example = lib.literalExpression ''
        {
          kubeconfig = "/etc/kubernetes/controller-manager.conf";
          leader-elect = true;
          leader-elect-resource-name = "kube-controller-manager";
          leader-elect-resource-namespace = "kube-system";
          cluster-name = "kubernetes";
        }
      '';
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Set defaults for controller-manager
    kubernetes.kube-controller-manager.args = {
      kubeconfig = lib.mkDefault "/etc/kubernetes/controller-manager.conf";
      leader-elect = lib.mkDefault true;
      leader-elect-resource-name = lib.mkDefault "kube-controller-manager";
      leader-elect-resource-namespace = lib.mkDefault "kube-system";
      cluster-name = lib.mkDefault "kubernetes";
    };
    
    systemd.services.kube-controller-manager = {
      wantedBy = [ "multi-user.target" ];
      after = [ "kube-apiserver.service" ];
      wants = [ "kube-apiserver.service" ];
      
      serviceConfig = {
        Type = "notify";
        
        ExecStart = 
          let
            args = lib.cli.toGNUCommandLineShell {} cfg.args;
          in
          "${lib.getExe' cfg.package "kube-controller-manager"} ${args}";
        
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
