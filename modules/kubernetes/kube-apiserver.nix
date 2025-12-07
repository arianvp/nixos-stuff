{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.kubernetes.kube-apiserver;
  k8sFormats = import ./formats { inherit lib pkgs; };

  # Generate optional config files
  authenticationConfigFile = lib.mapNullable (k8sFormats.kubeApiserverConfigurations.authenticationConfiguration.generate "authentication-config.yaml") cfg.authenticationConfig;

  authorizationConfigFile = lib.mapNullable (k8sFormats.kubeApiserverConfigurations.authorizationConfiguration.generate "authorization-config.yaml") cfg.authorizationConfig;

  admissionConfigFile = lib.mapNullable (k8sFormats.kubeApiserverConfigurations.admissionConfiguration.generate "admission-config.yaml") cfg.admissionConfig;

  encryptionConfigFile = lib.mapNullable (k8sFormats.kubeApiserverConfigurations.encryptionConfiguration.generate "encryption-config.yaml") cfg.encryptionConfig;

  tracingConfigFile = lib.mapNullable (k8sFormats.kubeApiserverConfigurations.tracingConfiguration.generate "tracing-config.yaml") cfg.tracingConfig;
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
      type = lib.types.attrsOf (
        lib.types.nullOr (
          lib.types.oneOf [
            lib.types.str
            lib.types.int
            lib.types.bool
            lib.types.path
            (lib.types.listOf lib.types.str)
          ]
        )
      );
      default = { };
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
  };

  config = lib.mkIf cfg.enable {
    # Set defaults for kube-apiserver
    kubernetes.kube-apiserver.args = {
      authentication-config = authenticationConfigFile;
      authorization-config = authorizationConfigFile;
      admission-control-config-file = admissionConfigFile;
      encryption-provider-config = encryptionConfigFile;
      tracing-config-file = tracingConfigFile;
    };

    systemd.services.kube-apiserver = lib.mkMerge [{
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "notify";
        WatchdogSec = "30s";
        RuntimeDirectory = "kubernetes";
        ExecStart =
          let
            args = lib.cli.toGNUCommandLineShell { } cfg.args;
          in
          "${lib.getExe' cfg.package "kube-apiserver"} ${args}";

        Restart = "on-failure";
        RestartSec = "5s";
      };
    }
    # TODO: Only when advertise-addr is unset
    (lib.mkIf true {
      # Fixes: Unable to find suitable network address.error='no default routes
      # found in "/proc/net/route" or "/proc/net/ipv6_route"'. Try to set the
      # AdvertiseAddress directly or provide a valid BindAddress to fix this.
      requires = [ "network-online.target" ];
      after = [ "network-online.target" ];
    })];
  };
}
