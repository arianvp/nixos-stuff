{ pkgs, lib, config, ... }:

let
  cfg = config.kubernetes.kube-apiserver;
  k8sFormats = import ./formats { inherit lib pkgs; };
  
  # Generate optional config files
  authenticationConfigFile = lib.optionalAttrs (cfg.authenticationConfig != null)
    (k8sFormats.kubeApiserverConfigurations.authenticationConfiguration.generate 
      "authentication-config.yaml" cfg.authenticationConfig);
  
  authorizationConfigFile = lib.optionalAttrs (cfg.authorizationConfig != null)
    (k8sFormats.kubeApiserverConfigurations.authorizationConfiguration.generate 
      "authorization-config.yaml" cfg.authorizationConfig);
  
  admissionConfigFile = lib.optionalAttrs (cfg.admissionConfig != null)
    (k8sFormats.kubeApiserverConfigurations.admissionConfiguration.generate 
      "admission-config.yaml" cfg.admissionConfig);
  
  encryptionConfigFile = lib.optionalAttrs (cfg.encryptionConfig != null)
    (k8sFormats.kubeApiserverConfigurations.encryptionConfiguration.generate 
      "encryption-config.yaml" cfg.encryptionConfig);
  
  tracingConfigFile = lib.optionalAttrs (cfg.tracingConfig != null)
    (k8sFormats.kubeApiserverConfigurations.tracingConfiguration.generate 
      "tracing-config.yaml" cfg.tracingConfig);
in
{
  options.kubernetes.kube-apiserver = {
    enable = lib.mkEnableOption "kube-apiserver";
    
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.kubernetes;
      description = "Kubernetes package to use";
    };
    
    # Configuration files
    authenticationConfig = lib.mkOption {
      type = lib.types.nullOr k8sFormats.kubeApiserverConfigurations.authenticationConfiguration.type;
      default = null;
      description = ''
        Authentication configuration for kube-apiserver.
        See https://kubernetes.io/docs/reference/config-api/apiserver-config.v1/#apiserver-k8s-io-v1-AuthenticationConfiguration
      '';
    };
    
    authorizationConfig = lib.mkOption {
      type = lib.types.nullOr k8sFormats.kubeApiserverConfigurations.authorizationConfiguration.type;
      default = null;
      description = ''
        Authorization configuration for kube-apiserver.
        See https://kubernetes.io/docs/reference/config-api/apiserver-config.v1/#apiserver-k8s-io-v1-AuthorizationConfiguration
      '';
    };
    
    admissionConfig = lib.mkOption {
      type = lib.types.nullOr k8sFormats.kubeApiserverConfigurations.admissionConfiguration.type;
      default = null;
      description = ''
        Admission configuration for kube-apiserver.
        See https://kubernetes.io/docs/reference/config-api/apiserver-config.v1/#apiserver-k8s-io-v1-AdmissionConfiguration
      '';
    };
    
    encryptionConfig = lib.mkOption {
      type = lib.types.nullOr k8sFormats.kubeApiserverConfigurations.encryptionConfiguration.type;
      default = null;
      description = ''
        Encryption configuration for kube-apiserver.
        See https://kubernetes.io/docs/reference/config-api/apiserver-config.v1/#apiserver-k8s-io-v1-EncryptionConfiguration
      '';
    };
    
    tracingConfig = lib.mkOption {
      type = lib.types.nullOr k8sFormats.kubeApiserverConfigurations.tracingConfiguration.type;
      default = null;
      description = ''
        Tracing configuration for kube-apiserver.
        See https://kubernetes.io/docs/reference/config-api/apiserver-config.v1/#TracingConfiguration
      '';
    };
    
    # Command-line arguments
    args = lib.mkOption {
      type = lib.types.attrsOf (lib.types.oneOf [ lib.types.str lib.types.int lib.types.bool (lib.types.listOf lib.types.str) ]);
      default = {};
      description = "Command-line arguments to pass to kube-apiserver";
      example = lib.literalExpression ''
        {
          etcd-servers = "https://[::1]:2379";
          service-account-issuer = "https://kubernetes.default.svc";
          service-account-key-file = "/etc/kubernetes/pki/sa.pub";
          service-account-signing-key-file = "/etc/kubernetes/pki/sa.key";
          bind-address = "::";
        }
      '';
    };
    
    extraArgs = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional command-line arguments";
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Set defaults for kube-apiserver
    kubernetes.kube-apiserver.args = {
      # etcd
      etcd-servers = lib.mkDefault "http://localhost:2379";
      
      # Service account configuration
      service-account-issuer = lib.mkDefault "https://spire.nixos.sh";
      # TODO: delegate signing to SPIRE: https://github.com/kubernetes/enhancements/tree/master/keps/sig-auth/740-service-account-external-signing
      # service-account-signing-endpoint = "/run/signing.sock";
      
      # Used to verify. When unset; defaults to --tls-private-key-file
      service-account-key-file = lib.mkDefault "/var/lib/kubernetes/sa.key";
      # Used to sign
      service-account-signing-key-file = lib.mkDefault "/var/lib/kubernetes/sa.key";
      # The default; but conceptually wrong when the issuer is external.
      # TODO: change to the cluster api server address in the future
      api-audiences = lib.mkDefault [ "https://spire.nixos.sh" ];
      
      # Bind address
      bind-address = lib.mkDefault "::";
      # advertise-address is auto-detected
      
      # TODO: Authentication
      # TODO: Authorization
    } // lib.optionalAttrs (cfg.authenticationConfig != null) {
      authentication-config = authenticationConfigFile;
    } // lib.optionalAttrs (cfg.authorizationConfig != null) {
      authorization-config = authorizationConfigFile;
    } // lib.optionalAttrs (cfg.admissionConfig != null) {
      admission-control-config-file = admissionConfigFile;
    } // lib.optionalAttrs (cfg.encryptionConfig != null) {
      encryption-provider-config = encryptionConfigFile;
    } // lib.optionalAttrs (cfg.tracingConfig != null) {
      tracing-config-file = tracingConfigFile;
    };
    
    systemd.services.kube-apiserver = {
      wantedBy = [ "multi-user.target" ];
      # Fixes: Unable to find suitable network address.error='no default routes
      # found in "/proc/net/route" or "/proc/net/ipv6_route"'. Try to set the
      # AdvertiseAddress directly or provide a valid BindAddress to fix this.
      requires = [ "network-online.target" ];
      after = [ "network-online.target" ];
      
      serviceConfig = {
        Type = "notify";
        WatchdogSec = "30s";
        RuntimeDirectory = "kubernetes";
        StateDirectory = "kubernetes";
        
        # TODO: Key persistence or out-source to SPIRE
        ExecStartPre = lib.mkIf (cfg.args.service-account-key-file == "/var/lib/kubernetes/sa.key") (
          pkgs.writeShellScript "generate-sa-key" ''
            if [ ! -f /var/lib/kubernetes/sa.key ]; then
              ${pkgs.openssl}/bin/openssl ecparam -genkey -name prime256v1 -out /var/lib/kubernetes/sa.key
              ${pkgs.openssl}/bin/openssl ec -in /var/lib/kubernetes/sa.key -pubout -out /var/lib/kubernetes/sa.pub
            fi
          ''
        );
        
        ExecStart = 
          let
            args = lib.cli.toGNUCommandLineShell {} (cfg.args // cfg.extraArgs);
          in
          "${lib.getExe' cfg.package "kube-apiserver"} ${args}";
        
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
