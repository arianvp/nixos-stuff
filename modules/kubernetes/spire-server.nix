# The SPIRE server side of kubernetes.spire: registers the entries the nodes
# ask for, and makes their X509-SVIDs usable by Kubernetes, which takes users
# and groups from the subject and is reached by IP address from pods.
{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.kubernetes.spire.server;
  trustDomain = config.services.spire.server.settings.server.trust_domain;
  prefix = "spiffe://${lib.escapeRegex trustDomain}/k8s";

  composerConfig = (pkgs.formats.json { }).generate "spire-credentialcomposer-x509.json" {
    subjects = [
      {
        spiffe_id = "${prefix}/node/([^/]+)";
        common_name = "system:node:$1";
        organizations = [ "system:nodes" ];
      }
      {
        spiffe_id = "${prefix}/system/([^/]+)";
        common_name = "system:$1";
      }
      {
        spiffe_id = "${prefix}/admin/([^/]+)";
        common_name = "$1";
        organizations = [ "system:masters" ];
      }
      {
        # The user the kubelets authorize
        spiffe_id = "${prefix}/kube-apiserver/[^/]+";
        common_name = "kube-apiserver";
      }
      {
        spiffe_id = "(spiffe://.+)";
        common_name = "$1";
      }
    ];
    ip_addresses = lib.listToAttrs (
      lib.concatMap (
        entry:
        lib.optional (entry.ipAddresses or [ ] != [ ]) (lib.nameValuePair entry.spiffeID entry.ipAddresses)
      ) (lib.attrValues cfg.entries)
    );
  };
in
{
  imports = [ ../spire/controller-manager.nix ];

  options.kubernetes.spire.server = {
    enable = lib.mkEnableOption ''
      registering Kubernetes workloads with this SPIRE server and composing
      their X509-SVIDs for Kubernetes. SPIFFE IDs map to Kubernetes users as
      follows:

      - `spiffe://<td>/k8s/node/<name>`: `system:node:<name>` in `system:nodes`
      - `spiffe://<td>/k8s/system/<name>`: `system:<name>`
      - `spiffe://<td>/k8s/admin/<name>`: `<name>` in `system:masters`
      - any other SPIFFE ID: the SPIFFE ID itself
    '';

    entries = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = ''
        The {option}`kubernetes.spire.entries` of all nodes of the cluster.
      '';
      example = lib.literalExpression ''
        lib.mkMerge (map (node: node.config.kubernetes.spire.entries) nodes)
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.spire.controllerManager = {
      enable = true;
      staticEntries = lib.mapAttrs (_: entry: {
        spec = {
          inherit (entry)
            spiffeID
            parentID
            selectors
            dnsNames
            ;
        };
      }) cfg.entries;
    };

    services.spire.server.settings.plugins.CredentialComposer.x509 = {
      plugin_cmd = lib.getExe pkgs.spire-credentialcomposer-x509;
      plugin_data_file = "${composerConfig}";
    };
  };
}
