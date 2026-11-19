{
  pkgs,
  lib,
  ...
}:
let
  k8sFormats = import ./formats { inherit lib pkgs; };
in
{
  options.kubernetes.kubeconfigs = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        {
          name,
          config,
          ...
        }:
        {
          options = {
            file = lib.mkOption {
              type = lib.types.path;
              readOnly = true;
              default = k8sFormats.kubeconfig.generate "${name}.conf" config.settings;
              description = "The generated kubeconfig file";
            };

            settings = lib.mkOption {
              type = k8sFormats.kubeconfig.type;
              description = "Kubeconfig settings";
            };

            clusterMap = lib.mkOption {
              type = lib.types.attrsOf k8sFormats.kubeconfig.types.clusterType;
              description = "Map of cluster name to cluster configuration";
            };

            userMap = lib.mkOption {
              type = lib.types.attrsOf k8sFormats.kubeconfig.types.authInfoType;
              description = "Map of user name to user configuration";
            };

            contextMap = lib.mkOption {
              type = lib.types.attrsOf k8sFormats.kubeconfig.types.contextType;
              description = "Map of context name to context configuration";
            };
          };

          config.settings = {
            clusters = lib.mapAttrsToList (name: cluster: { inherit name cluster; }) config.clusterMap;
            contexts = lib.mapAttrsToList (name: context: { inherit name context; }) config.contextMap;
            users = lib.mapAttrsToList (name: user: { inherit name user; }) config.userMap;
          };
        }
      )
    );
    default = { };
    description = ''
      Kubeconfig files to generate.

      Each attribute name becomes the filename (with .conf appended).
    '';
  };
}
