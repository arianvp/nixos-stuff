{
  pkgs,
  lib,
  options,
  config,
  ...
}:

let
  k8sFormats = import ./formats { inherit lib pkgs; };
in
{
  options.kubernetes.kubeconfigs = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { config, options,... }:
        {
          options = {
            settings = lib.mkOption {
              type = k8sFormats.kubeconfig.type;
              description = "Kubeconfig settings";
            };

            clusterMap = lib.mkOption {
              # TODO: I can probably access this type through options instead
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

          config = {
            settings = {
              clusters = lib.mapAttrsToList (name: cluster: {
                inherit name;
                cluster = cluster;
              }) config.clusterMap;

              contexts = lib.mapAttrsToList (name: context: {
                inherit name;
                context = context;
              }) config.contextMap;

              users = lib.mapAttrsToList (name: user: {
                inherit name;
                user = user;
              }) config.userMap;
            };
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

  config.environment.etc = lib.mapAttrs' (
    name: value:
    lib.nameValuePair "kubernetes/${name}.conf" {
      source = k8sFormats.kubeconfig.generate "${name}.conf" value.settings;
    }
  ) config.kubernetes.kubeconfigs;
}
