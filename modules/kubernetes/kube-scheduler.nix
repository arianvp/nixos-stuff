{ pkgs, lib, config, ... }:

let
  cfg = config.kubernetes.kube-scheduler;
  k8sFormats = import ./formats { inherit lib pkgs; };
  
  # Filter out null values to avoid empty strings in YAML
  filterNulls = attrs: lib.filterAttrsRecursive (n: v: v != null) attrs;
  
  schedulerConfigFile = k8sFormats.kubeSchedulerConfiguration.generate "scheduler-config.yaml" (filterNulls cfg.settings);
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
      default = {};
      description = ''
        Kube-scheduler configuration.
        See https://kubernetes.io/docs/reference/config-api/kube-scheduler-config.v1/
      '';
      example = lib.literalExpression ''
        {
          apiVersion = "kubescheduler.config.k8s.io/v1";
          kind = "KubeSchedulerConfiguration";
          
          clientConnection = {
            kubeconfig = "/etc/kubernetes/scheduler.conf";
          };
          
          leaderElection = {
            leaderElect = true;
            resourceName = "kube-scheduler";
            resourceNamespace = "kube-system";
          };
        }
      '';
    };
    
    extraArgs = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Extra command-line arguments to pass to kube-scheduler";
      example = { v = "2"; };
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Set defaults for scheduler configuration
    kubernetes.kube-scheduler.settings = {
      apiVersion = lib.mkDefault "kubescheduler.config.k8s.io/v1";
      kind = lib.mkDefault "KubeSchedulerConfiguration";
      
      clientConnection = lib.mkDefault {
        kubeconfig = "/etc/kubernetes/scheduler.conf";
      };
      
      leaderElection = lib.mkDefault {
        leaderElect = true;
        resourceName = "kube-scheduler";
        resourceNamespace = "kube-system";
      };
    };
    
    systemd.services.kube-scheduler = {
      wantedBy = [ "multi-user.target" ];
      after = [ "kube-apiserver.service" ];
      wants = [ "kube-apiserver.service" ];
      
      serviceConfig = {
        Type = "notify";
        
        ExecStart = 
          let
            args = lib.cli.toGNUCommandLineShell {} ({
              config = schedulerConfigFile;
            } // cfg.extraArgs);
          in
          "${lib.getExe' cfg.package "kube-scheduler"} ${args}";
        
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
