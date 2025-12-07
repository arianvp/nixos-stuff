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
  options.kubernetes.kube-controller-manager = {
    enable = lib.mkEnableOption "kube-controller-manager";
    
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.kubernetes;
      description = "Kubernetes package to use";
    };
    
    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = ''
        Kube-controller-manager configuration.
        
        NOTE: kube-controller-manager does NOT support --config flag.
        This structured configuration will be converted to command-line flags.
        
        See https://kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/
      '';
      example = lib.literalExpression ''
        {
          generic = {
            clientConnection.kubeconfig = "/etc/kubernetes/controller-manager.conf";
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
      generic = lib.mkDefault {
        clientConnection.kubeconfig = "/etc/kubernetes/controller-manager.conf";
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
            # Convert structured config to CLI args
            configArgs = flattenConfig cfg.settings;
            allArgs = configArgs // cfg.extraArgs;
            args = lib.cli.toGNUCommandLineShell {} allArgs;
          in
          "${lib.getExe' cfg.package "kube-controller-manager"} ${args}";
        
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
