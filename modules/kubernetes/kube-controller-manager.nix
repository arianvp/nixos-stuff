{ pkgs, lib, config, ... }:

let
  cfg = config.kubernetes.kube-controller-manager;
  k8sFormats = import ./formats { inherit lib pkgs; };
  
  controllerManagerConfigFile = k8sFormats.kubeControllerManagerConfiguration.generate "controller-manager-config.yaml" cfg.settings;
in
{
  options.kubernetes.kube-controller-manager = {
    enable = lib.mkEnableOption "kube-controller-manager";
    
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.kubernetes;
      description = "Kubernetes package to use";
    };
    
    settings = lib.mkOption {
      type = k8sFormats.kubeControllerManagerConfiguration.type;
      default = {};
      description = ''
        Kube-controller-manager configuration.
        See https://kubernetes.io/docs/reference/config-api/kube-controller-manager-config.v1alpha1/
      '';
      example = lib.literalExpression ''
        {
          apiVersion = "kubecontrollermanager.config.k8s.io/v1alpha1";
          kind = "KubeControllerManagerConfiguration";
          
          generic = {
            clientConnection = {
              kubeconfig = "/etc/kubernetes/controller-manager.conf";
            };
            leaderElection = {
              leaderElect = true;
              resourceName = "kube-controller-manager";
              resourceNamespace = "kube-system";
            };
          };
          
          kubeCloudShared = {
            clusterName = "kubernetes";
          };
        }
      '';
    };
    
    extraArgs = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Extra command-line arguments to pass to kube-controller-manager";
      example = { v = "2"; };
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Set defaults for controller-manager configuration
    kubernetes.kube-controller-manager.settings = {
      apiVersion = lib.mkDefault "kubecontrollermanager.config.k8s.io/v1alpha1";
      kind = lib.mkDefault "KubeControllerManagerConfiguration";
      
      generic = lib.mkDefault {
        clientConnection = {
          kubeconfig = "/etc/kubernetes/controller-manager.conf";
        };
        leaderElection = {
          leaderElect = true;
          resourceName = "kube-controller-manager";
          resourceNamespace = "kube-system";
        };
      };
      
      kubeCloudShared = lib.mkDefault {
        clusterName = "kubernetes";
      };
    };
    
    systemd.services.kube-controller-manager = {
      wantedBy = [ "multi-user.target" ];
      after = [ "kube-apiserver.service" ];
      wants = [ "kube-apiserver.service" ];
      
      serviceConfig = {
        Type = "notify";
        
        ExecStart = 
          let
            args = lib.cli.toGNUCommandLineShell {} ({
              config = controllerManagerConfigFile;
            } // cfg.extraArgs);
          in
          "${lib.getExe' cfg.package "kube-controller-manager"} ${args}";
        
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
