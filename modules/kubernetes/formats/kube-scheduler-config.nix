{ lib, pkgs }:

let
  format = pkgs.formats.yaml { };
  
  clientConnectionConfigurationType = lib.types.submodule {
    freeformType = format.type;
    options = {
      kubeconfig = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to kubeconfig file with authorization and server information";
        example = "/etc/kubernetes/scheduler.conf";
      };
      
      contentType = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Content type for requests sent to apiserver";
        example = "application/vnd.kubernetes.protobuf";
      };
      
      qps = lib.mkOption {
        type = lib.types.nullOr lib.types.float;
        default = null;
        description = "QPS to use while talking with kubernetes apiserver";
        example = 50.0;
      };
      
      burst = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Burst to use while talking with kubernetes apiserver";
        example = 100;
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
        example = "kube-scheduler";
      };
      
      resourceNamespace = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Namespace of the resource object used for locking";
        example = "kube-system";
      };
    };
  };
  
  kubeSchedulerProfileType = lib.types.submodule {
    freeformType = format.type;
    options = {
      schedulerName = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Name of the scheduler associated with this profile";
        example = "default-scheduler";
      };
      
      plugins = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "Plugin configuration for this profile";
      };
      
      pluginConfig = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf (lib.types.attrsOf lib.types.anything));
        default = null;
        description = "Plugin-specific configuration arguments";
      };
    };
  };
  
  kubeSchedulerConfigurationType = lib.types.submodule {
    freeformType = format.type;
    
    options = {
      apiVersion = lib.mkOption {
        type = lib.types.str;
        default = "kubescheduler.config.k8s.io/v1";
        description = "API version";
      };
      
      kind = lib.mkOption {
        type = lib.types.str;
        default = "KubeSchedulerConfiguration";
        description = "Resource kind";
      };
      
      parallelism = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Amount of parallelism in scheduling algorithms (must be > 0)";
        example = 16;
      };
      
      leaderElection = lib.mkOption {
        type = lib.types.nullOr leaderElectionConfigurationType;
        default = null;
        description = "Leader election configuration";
      };
      
      clientConnection = lib.mkOption {
        type = lib.types.nullOr clientConnectionConfigurationType;
        default = null;
        description = "Connection configuration for kubernetes clients";
      };
      
      percentageOfNodesToScore = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Percentage of all nodes to score before stopping search for more feasible nodes";
        example = 50;
      };
      
      podInitialBackoffSeconds = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Initial backoff for unschedulable pods (in seconds)";
        example = 1;
      };
      
      podMaxBackoffSeconds = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Maximum backoff for unschedulable pods (in seconds)";
        example = 10;
      };
      
      profiles = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf kubeSchedulerProfileType);
        default = null;
        description = "List of scheduling profiles";
      };
      
      extenders = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf (lib.types.attrsOf lib.types.anything));
        default = null;
        description = "List of scheduler extenders";
      };
      
      delayCacheUntilActive = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Delay populating informer caches until active in leader election";
      };
    };
  };
in
{
  type = kubeSchedulerConfigurationType;
  generate = name: value: format.generate name value;
}
