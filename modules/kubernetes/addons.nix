{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.kubernetes.addons;
  format = pkgs.formats.json { };

  manifests = format.generate "kubernetes-addons.json" {
    apiVersion = "v1";
    kind = "List";
    items = lib.attrValues cfg.manifests;
  };

  # What identifies each object, to delete the ones that were removed
  identities = format.generate "kubernetes-addons-identities.json" (
    map (manifest: {
      inherit (manifest) apiVersion kind;
      metadata = {
        inherit (manifest.metadata) name;
      }
      // lib.optionalAttrs (manifest.metadata ? namespace) { inherit (manifest.metadata) namespace; };
    }) (lib.attrValues cfg.manifests)
  );
in
{
  options.kubernetes.addons = {
    manifests = lib.mkOption {
      type = lib.types.attrsOf format.type;
      default = { };
      description = ''
        Kubernetes objects that are applied to the cluster with server-side
        apply whenever they change. Objects that are removed from this option
        are deleted from the cluster.
      '';
      example = lib.literalExpression ''
        {
          kubelet-api-admin = {
            apiVersion = "rbac.authorization.k8s.io/v1";
            kind = "ClusterRoleBinding";
            metadata.name = "kube-apiserver:kubelet-api-admin";
            roleRef = {
              apiGroup = "rbac.authorization.k8s.io";
              kind = "ClusterRole";
              name = "system:kubelet-api-admin";
            };
            subjects = [ { apiGroup = "rbac.authorization.k8s.io"; kind = "User"; name = "kube-apiserver"; } ];
          };
        }
      '';
    };

    kubeconfig = lib.mkOption {
      type = lib.types.str;
      description = "Kubeconfig with permission to apply the manifests.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.kubernetes;
      description = "Package providing kubectl.";
    };
  };

  config = lib.mkIf (cfg.manifests != { }) {
    systemd.services.kube-addons = {
      description = "Apply Kubernetes addon manifests";
      wantedBy = [ "multi-user.target" ];
      after = [ "kube-apiserver.service" ];
      restartTriggers = [ manifests ];
      # Keeps retrying while the API server comes up
      startLimitIntervalSec = 0;
      path = [
        cfg.package
        pkgs.jq
      ];
      environment.KUBECONFIG = cfg.kubeconfig;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "5s";
        StateDirectory = "kube-addons";
      };
      script = ''
        kubectl apply --server-side --force-conflicts --field-manager=nixos --filename ${manifests}

        applied=$STATE_DIRECTORY/applied.json
        if [ -e "$applied" ]; then
          jq --slurpfile current ${identities} \
            '{apiVersion: "v1", kind: "List", items: [.[] | select(. as $o | $current[0] | index([$o]) | not)]}' \
            "$applied" > "$STATE_DIRECTORY/removed.json"
          if [ "$(jq '.items | length' "$STATE_DIRECTORY/removed.json")" -gt 0 ]; then
            kubectl delete --ignore-not-found --filename "$STATE_DIRECTORY/removed.json"
          fi
        fi
        cp ${identities} "$applied"
      '';
    };
  };
}
