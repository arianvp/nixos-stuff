{ lib, pkgs }:

let
  format = pkgs.formats.yaml { };
  
  # Authentication sub-types
  kubeletAnonymousAuthType = lib.types.submodule {
    freeformType = format.type;
    options = {
      enabled = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Enable anonymous requests to the kubelet server";
      };
    };
  };
  
  kubeletX509AuthType = lib.types.submodule {
    freeformType = format.type;
    options = {
      clientCAFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to a PEM encoded CA bundle for client certificate verification";
        example = "/etc/kubernetes/pki/ca.crt";
      };
    };
  };
  
  kubeletWebhookAuthType = lib.types.submodule {
    freeformType = format.type;
    options = {
      enabled = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Enable bearer token authentication via webhook";
      };
      
      cacheTTL = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Duration to cache authentication results";
        example = "2m0s";
      };
    };
  };
  
  kubeletAuthenticationType = lib.types.submodule {
    freeformType = format.type;
    options = {
      anonymous = lib.mkOption {
        type = lib.types.nullOr kubeletAnonymousAuthType;
        default = null;
        description = "Anonymous authentication configuration";
      };
      
      webhook = lib.mkOption {
        type = lib.types.nullOr kubeletWebhookAuthType;
        default = null;
        description = "Webhook bearer token authentication configuration";
      };
      
      x509 = lib.mkOption {
        type = lib.types.nullOr kubeletX509AuthType;
        default = null;
        description = "X509 client certificate authentication configuration";
      };
    };
  };
  
  kubeletWebhookAuthzType = lib.types.submodule {
    freeformType = format.type;
    options = {
      cacheAuthorizedTTL = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Duration to cache 'authorized' responses from the webhook";
        example = "5m0s";
      };
      
      cacheUnauthorizedTTL = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Duration to cache 'unauthorized' responses from the webhook";
        example = "30s";
      };
    };
  };
  
  kubeletAuthorizationType = lib.types.submodule {
    freeformType = format.type;
    options = {
      mode = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "AlwaysAllow" "Webhook" ]);
        default = null;
        description = "Authorization mode for kubelet server requests";
      };
      
      webhook = lib.mkOption {
        type = lib.types.nullOr kubeletWebhookAuthzType;
        default = null;
        description = "Webhook authorization configuration";
      };
    };
  };
  
  kubeletConfigurationType = lib.types.submodule {
    freeformType = format.type;
    
    options = {
      apiVersion = lib.mkOption {
        type = lib.types.str;
        default = "kubelet.config.k8s.io/v1beta1";
        description = "API version";
      };
      
      kind = lib.mkOption {
        type = lib.types.str;
        default = "KubeletConfiguration";
        description = "Resource kind";
      };
      
      # Server configuration
      enableServer = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Enable the kubelet's secured server";
      };
      
      address = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "IP address for the kubelet to serve on";
        example = "::";
      };
      
      port = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Port for the kubelet to serve on";
        example = 10250;
      };
      
      readOnlyPort = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Read-only port for the kubelet to serve on (0 to disable)";
      };
      
      # TLS
      tlsCertFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to x509 certificate for HTTPS";
        example = "/var/lib/kubelet/pki/kubelet.crt";
      };
      
      tlsPrivateKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to x509 private key matching tlsCertFile";
        example = "/var/lib/kubelet/pki/kubelet.key";
      };
      
      rotateCertificates = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Enable client certificate rotation";
      };
      
      serverTLSBootstrap = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Request server certificate from API server";
      };
      
      # Authentication and Authorization
      authentication = lib.mkOption {
        type = lib.types.nullOr kubeletAuthenticationType;
        default = null;
        description = "Kubelet server authentication configuration";
      };
      
      authorization = lib.mkOption {
        type = lib.types.nullOr kubeletAuthorizationType;
        default = null;
        description = "Kubelet server authorization configuration";
      };
      
      # Cluster configuration
      clusterDomain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Cluster DNS domain";
        example = "cluster.local";
      };
      
      clusterDNS = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "IP addresses for cluster DNS service";
        example = [ "10.96.0.10" ];
      };
      
      # Runtime configuration
      containerRuntimeEndpoint = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Endpoint of container runtime service";
        example = "unix:///run/crio/crio.sock";
      };
      
      cgroupDriver = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "cgroupfs" "systemd" ]);
        default = null;
        description = "Cgroup driver used by the kubelet";
      };
      
      # System configuration
      resolvConf = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Resolver configuration file";
        example = "/run/systemd/resolve/resolv.conf";
      };
      
      # Pod configuration
      staticPodPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to directory containing static pod manifests";
        example = "/etc/kubernetes/manifests";
      };
      
      maxPods = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Maximum number of pods that can run on this kubelet";
        example = 110;
      };
      
      podPidsLimit = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Maximum number of PIDs in any pod (-1 for unlimited)";
      };
      
      # Image management
      serializeImagePulls = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Pull images one at a time (recommended for most scenarios)";
      };
      
      maxParallelImagePulls = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Maximum number of parallel image pulls (requires serializeImagePulls=false)";
      };
      
      registryPullQPS = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "QPS limit for registry pulls (0 for unlimited)";
      };
      
      registryBurst = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Maximum burst for registry pulls";
      };
      
      # Event handling
      eventRecordQPS = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "QPS limit for event creations";
      };
      
      eventBurst = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Maximum burst for event creations";
      };
      
      # Sync frequencies
      syncFrequency = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Maximum period for syncing running containers and config";
        example = "1m";
      };
      
      fileCheckFrequency = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Duration between checking config files";
        example = "20s";
      };
      
      # Resource management
      systemReserved = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
        default = null;
        description = "Resources reserved for system daemons";
        example = { cpu = "100m"; memory = "128Mi"; };
      };
      
      kubeReserved = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
        default = null;
        description = "Resources reserved for kubernetes components";
        example = { cpu = "100m"; memory = "128Mi"; };
      };
      
      # Eviction thresholds
      evictionHard = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
        default = null;
        description = "Hard eviction thresholds";
        example = {
          "memory.available" = "100Mi";
          "nodefs.available" = "10%";
          "imagefs.available" = "15%";
        };
      };
      
      evictionSoft = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
        default = null;
        description = "Soft eviction thresholds";
      };
      
      evictionSoftGracePeriod = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
        default = null;
        description = "Grace periods for soft eviction thresholds";
      };
      
      # Logging
      containerLogMaxSize = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Maximum size of container log files before rotation";
        example = "10Mi";
      };
      
      containerLogMaxFiles = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Maximum number of container log files to retain per container";
        example = 5;
      };
      
      # Feature gates
      featureGates = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.bool);
        default = null;
        description = "Feature gates to enable/disable";
        example = { RotateKubeletServerCertificate = true; };
      };
      
      # Shutdown configuration
      shutdownGracePeriod = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Total duration kubelet will wait before shutting down";
        example = "30s";
      };
      
      shutdownGracePeriodCriticalPods = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Duration for critical pods to terminate during shutdown";
        example = "10s";
      };
    };
  };
in
{
  type = kubeletConfigurationType;
  generate = name: value: format.generate name value;
}
