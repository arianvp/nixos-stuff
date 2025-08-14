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
    trustDomain = config.spire.server.trustDomain;

    # TODO: I don't think this *does* anything in static manifest mode but it's required
    clusterName = "scm";
    clusterDomain = "local";

    # TODO: Config
    spireServerSocketPath = "/run/spire-server/private/api.sock";
    staticManifestPath = "/etc/spire/server/manifests";
  };
  format = pkgs.formats.yaml { };

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

    manifests = lib.mkOption {
      type = lib.types.listOf format.type;
      default = [ ];
      description = "SPIRE Controller Manager manifests";
    };

  };

  config = lib.mkIf cfg.enable {

    environment.etc = lib.listToAttrs (
      map (
        manifest:
        lib.nameValuePair "spire/server/manifests/${manifest.metadata.name}.yaml" {
          source = format.generate "${manifest.metadata.name}.yaml" manifest;
        }
      ) cfg.manifests
    );

    systemd.services.spire-controller-manager = {
      wantedBy = [ "multi-user.target" ];
      description = "SPIRE Controller Manager";
      serviceConfig.ExecStart = "${pkgs.spire-controller-manager}/bin/spire-controller-manager -config ${cfg.configFile}";
    };
  };
}
