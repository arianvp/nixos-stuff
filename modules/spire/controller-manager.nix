{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.spire.controllerManager;
  settings = {
    apiVersion = "spire.spiffe.io/v1alpha1";
    kind = "ControllerManagerConfig";
    metadata.name = "config";
    trustDomain = config.spire.server.settings.server.trust_domain;

    # TODO: I don't think this *does* anything in static manifest mode but it's required
    clusterName = "scm";
    clusterDomain = "local";

    spireServerSocketPath = config.spire.server.settings.server.socket_path;
    staticManifestPath = "/etc/spire/server/manifests";
    expandEnvStaticManifests = true;
  };
  format = pkgs.formats.yaml { };

  staticEntry =
    { name, config, ... }:
    {
      freeformType = format.type;
      options.spec = {
        spiffeID = lib.mkOption {
          type = lib.types.str;
          description = "The SPIFFE ID of the workload or node alias";
          example = "spiffe://example.org/myworkload";
          default = "spiffe://${cfg.settings.trustDomain}/${config.path}";
          defaultText = "spiffe://\${config.spire.controllerManager.settings.trustDomain}/\${staticEntry.path}";
        };

        parentID = lib.mkOption {
          type = lib.types.str;
          description = "The parent ID of the node or nodes authorized for the entry or the SPIRE server ID for a node alias";
          example = "spiffe://example.org/spire/agent/x509pop/12345";
        };

        selectors = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "One or more workload selectors (when registering a workload) or node selectors (when registering a node alias)";
          example = [
            "unix:uid:1001"
            "docker:image_id:123abc"
          ];
        };

        federatesWith = lib.mkOption {
          type = lib.types.nullOr (lib.types.listOf lib.types.str);
          default = null;
          description = "One or more trust domain names that target workloads federate with";
          example = [
            "federated.example.org"
            "partner.example.com"
          ];
        };

        # TODO: The upstream spec doesn't use  *metav1.Duration `json:omitempty` which causes
        # it to try to parse null as the empty string and crash
        /*
          x509SVIDTTL = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Duration value indicating an upper bound on the time-to-live for X509-SVIDs issued to target workload";
            example = "1h";
          };

          jwtSVIDTTL = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Duration value indicating an upper bound on the time-to-live for JWT-SVIDs issued to target workload";
            example = "5m";
            };
        */

        dnsNames = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "One or more DNS names for the target workload";
          example = [
            "myservice.example.org"
            "api.myservice.example.org"
          ];
        };

        hint = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "An opaque string that is provided to the workload as a hint on how the SVID should be used";
          example = "internal";
        };

        admin = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Indicates whether the target workload is an admin workload (i.e. can access SPIRE administrative APIs)";
        };

        downstream = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Indicates that the entry describes a downstream SPIRE server";
        };

        storeSVID = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Indicates whether the issued SVID must be stored through an SVIDStore plugin";
        };
      };
      config = {
        apiVersion = "spire.spiffe.io/v1alpha1";
        kind = "ClusterStaticEntry";
        metadata = { inherit name; };
      };
    };

in

{
  options.spire.controllerManager = {
    enable = lib.mkEnableOption "SPIRE Controller Manager";
    settings = lib.mkOption {
      type = format.type;
      default = settings;
      description = "SPIRE Controller Manager settings";
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      default = format.generate "config.yaml" cfg.settings;
      description = "Path to the SPIRE server configuration file.";
    };

    staticEntries = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule staticEntry);
      default = { };
      description = "SPIRE static entries to be created";
      example = {
        myWorkload = {
          spiffeID = "spiffe://example.org/myworkload";
          parentID = "spiffe://example.org/spire/agent/x509pop/12345";
          selectors = [
            "unix:uid:1001"
            "docker:image_id:123abc"
          ];
          federatesWith = [ "federated.example.org" ];
          x509SVIDTTL = "1h";
          jwtSVIDTTL = "5m";
          dnsNames = [ "myservice.example.org" ];
          admin = false;
        };
        adminWorkload = {
          spiffeID = "spiffe://example.org/admin";
          parentID = "spiffe://example.org/spire/agent/x509pop/67890";
          selectors = [ "unix:uid:0" ];
          admin = true;
        };
      };
    };

  };

  config = lib.mkIf (cfg.enable && cfg.staticEntries != { }) {
    environment.etc = lib.mapAttrs' (
      name: value:
      lib.nameValuePair "spire/server/manifests/${name}.yaml" {
        source = format.generate "${name}.yaml" value;
      }
    ) cfg.staticEntries;

    systemd.services.spire-controller-manager = {
      wantedBy = [ "multi-user.target" ];
      description = "SPIRE Controller Manager";
      serviceConfig.ExecStart = "${lib.getExe pkgs.spire-controller-manager} -config ${cfg.configFile}";
    };
  };
}
