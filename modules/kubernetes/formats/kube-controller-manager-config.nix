{ lib, pkgs }:

let
  format = pkgs.formats.yaml { };
  
  clientConnectionConfigurationType = lib.types.submodule {
    freeformType = format.type;
    options = {
      kubeconfig = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to kubeconfig file";
        example = "/etc/kubernetes/controller-manager.conf";
      };
      
      contentType = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Content type for requests sent to apiserver";
      };
      
      qps = lib.mkOption {
        type = lib.types.nullOr lib.types.float;
        default = null;
        description = "QPS to use while talking with kubernetes apiserver";
      };
      
      burst = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Burst to use while talking with kubernetes apiserver";
      };
    };
  };
  
  leaderElectionConfigurationType = lib.types.submodule {
    freeformType = format.type;
    options = {
      leaderElect = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Start a leader election client and gain leadership before executing";
      };
      
      leaseDuration = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Duration that non-leader candidates will wait to force acquire leadership";
        example = "15s";
      };
      
      renewDeadline = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Duration the acting leader will retry refreshing leadership before giving up";
        example = "10s";
      };
      
      retryPeriod = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Duration the LeaderElector clients should wait between tries of actions";
        example = "2s";
      };
      
      resourceLock = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "leases" "endpointsleases" "configmapsleases" ]);
        default = null;
        description = "Type of resource object used for locking during leader election";
      };
      
      resourceName = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Name of the resource object used for locking";
        example = "kube-controller-manager";
      };
      
      resourceNamespace = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Namespace of the resource object used for locking";
        example = "kube-system";
      };
    };
  };
  
  genericControllerManagerConfigurationType = lib.types.submodule {
    freeformType = format.type;
    options = {
      port = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Port to bind the controller manager's HTTP service";
        example = 10257;
      };
      
      address = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "IP address to serve on";
        example = "0.0.0.0";
      };
      
      minResyncPeriod = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Minimum reflector resync period";
        example = "12h";
      };
      
      clientConnection = lib.mkOption {
        type = lib.types.nullOr clientConnectionConfigurationType;
        default = null;
        description = "Connection configuration for kubernetes clients";
      };
      
      leaderElection = lib.mkOption {
        type = lib.types.nullOr leaderElectionConfigurationType;
        default = null;
        description = "Leader election configuration";
      };
      
      controllers = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "List of controllers to enable";
        example = [ "*" "tokencleaner" ];
      };
    };
  };
  
  kubeCloudSharedConfigurationType = lib.types.submodule {
    freeformType = format.type;
    options = {
      cloudProvider = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Name of the cloud provider";
      };
      
      clusterName = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Name of the cluster (used as a prefix for cloud provider resources)";
      };
      
      clusterCIDR = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "CIDR range for pods in cluster";
        example = "10.244.0.0/16";
      };
      
      allocateNodeCIDRs = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Enable CIDR allocation for nodes";
      };
      
      configureCloudRoutes = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Enable route configuration in cloud provider";
      };
      
      nodeMonitorPeriod = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Period for syncing NodeStatus in NodeController";
        example = "5s";
      };
    };
  };
  
  serviceControllerConfigurationType = lib.types.submodule {
    freeformType = format.type;
    options = {
      concurrentServiceSyncs = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Number of service objects that are allowed to sync concurrently";
        example = 1;
      };
    };
  };
  
  kubeControllerManagerConfigurationType = lib.types.submodule {
    freeformType = format.type;
    
    options = {
      apiVersion = lib.mkOption {
        type = lib.types.str;
        default = "kubecontrollermanager.config.k8s.io/v1alpha1";
        description = "API version";
      };
      
      kind = lib.mkOption {
        type = lib.types.str;
        default = "KubeControllerManagerConfiguration";
        description = "Resource kind";
      };
      
      generic = lib.mkOption {
        type = lib.types.nullOr genericControllerManagerConfigurationType;
        default = null;
        description = "Generic controller manager configuration";
      };
      
      kubeCloudShared = lib.mkOption {
        type = lib.types.nullOr kubeCloudSharedConfigurationType;
        default = null;
        description = "Cloud-related configuration shared by kube-controller-manager";
      };
      
      serviceController = lib.mkOption {
        type = lib.types.nullOr serviceControllerConfigurationType;
        default = null;
        description = "Service controller configuration";
      };
      
      # Additional controller-specific configurations can be added as needed
      attachDetachController = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "AttachDetachController configuration";
      };
      
      csrSigningController = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "CSRSigningController configuration";
      };
      
      daemonSetController = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "DaemonSetController configuration";
      };
      
      deploymentController = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "DeploymentController configuration";
      };
      
      endpointController = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "EndpointController configuration";
      };
      
      garbageCollectorController = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "GarbageCollectorController configuration";
      };
      
      hpaController = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "HPAController configuration";
      };
      
      jobController = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "JobController configuration";
      };
      
      namespaceController = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "NamespaceController configuration";
      };
      
      nodeIPAMController = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "NodeIPAMController configuration";
      };
      
      nodeLifecycleController = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "NodeLifecycleController configuration";
      };
      
      persistentVolumeBinderController = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "PersistentVolumeBinderController configuration";
      };
      
      podGCController = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "PodGCController configuration";
      };
      
      replicaSetController = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "ReplicaSetController configuration";
      };
      
      replicationController = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "ReplicationController configuration";
      };
      
      resourceQuotaController = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "ResourceQuotaController configuration";
      };
      
      saController = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "SAController (ServiceAccount controller) configuration";
      };
      
      statefulSetController = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "StatefulSetController configuration";
      };
      
      ttlAfterFinishedController = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "TTLAfterFinishedController configuration";
      };
    };
  };
in
{
  type = kubeControllerManagerConfigurationType;
  generate = name: value: format.generate name value;
}
