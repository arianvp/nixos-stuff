{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.kubernetes.kube-controller-manager;
  k8sLib = import ./lib.nix { inherit lib; };

  unitOf = group: "kube-controller-manager-${group}";
  # By convention, whoever gives a group an identity names its kubeconfig after
  # the instance that runs it
  kubeconfigOf = group: "${config.kubernetes.kubeconfigs.${unitOf group}.file}";

  service = description: args: {
    inherit description;
    wantedBy = [ "multi-user.target" ];
    after = [ "kube-apiserver.service" ];

    serviceConfig = {
      ExecStart = "${lib.getExe' cfg.package "kube-controller-manager"} ${k8sLib.toArgs args}";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
in
{
  options.kubernetes.kube-controller-manager = {
    enable = lib.mkEnableOption "kube-controller-manager";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.kubernetes;
      description = "Kubernetes package to use";
    };

    args = lib.mkOption {
      type = k8sLib.argsType;
      default = { };
      description = ''
        Command-line arguments to pass to kube-controller-manager.

        kube-controller-manager has no configuration file; all configuration is
        done with flags.

        See https://kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/
      '';
      example = lib.literalExpression ''
        {
          kubeconfig = "/etc/kubernetes/controller-manager.conf";
          leader-elect = true;
          cluster-name = "kubernetes";
        }
      '';
    };

    groups = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, config, ... }:
          {
            options = {
              controllers = lib.mkOption {
                type = lib.types.listOf (
                  lib.types.submodule {
                    options = {
                      name = lib.mkOption {
                        type = lib.types.str;
                        description = "The controller, as {option}`args.controllers` names it.";
                      };

                      role = lib.mkOption {
                        type = lib.types.str;
                        description = ''
                          The built-in `system:controller:<role>` cluster role to
                          grant for it. Kubernetes names those roles after neither
                          the controllers nor each other, so this is not always
                          {option}`name`: `daemonset-controller` has the role
                          `daemon-set-controller`.
                        '';
                      };
                    };
                  }
                );
                description = "Controllers to run, with the cluster role each needs.";
                example = lib.literalExpression ''
                  [
                    {
                      name = "daemonset-controller";
                      role = "daemon-set-controller";
                    }
                  ]
                '';
              };

              args = lib.mkOption {
                type = k8sLib.argsType;
                description = ''
                  Arguments of this instance. They default to {option}`args` with
                  the instance's own controllers, lease and kubeconfig, and the
                  serving port off, as only one instance can have it. Set
                  `secure-port` to serve metrics and health on a port of its own.
                '';
              };
            };

            config.args = cfg.args // {
              controllers = map (controller: controller.name) config.controllers;
              leader-elect-resource-name = unitOf name;
              # Only one instance can have the port, and the main one serves
              # metrics and health already
              secure-port = 0;
              # Running under an identity of its own is the point of a group
              kubeconfig = kubeconfigOf name;
              authentication-kubeconfig = kubeconfigOf name;
              authorization-kubeconfig = kubeconfigOf name;
            };
          }
        )
      );
      default = { };
      description = ''
        Instances that each run a subset of the controllers under an identity of
        their own, so that a controller cannot act beyond the permissions of its
        own group. The main instance runs the controllers no group claims. Every
        instance holds a lease of its own, so each runs on one node at a time.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    kubernetes.kube-controller-manager.args = {
      leader-elect = lib.mkDefault true;
      cluster-name = lib.mkDefault "kubernetes";
      # Negative, so that controllers a later Kubernetes adds still run
      # (attrNames, as comparing the groups themselves forces every one of them)
      controllers = lib.mkIf (lib.attrNames cfg.groups != [ ]) (
        [ "*" ]
        ++ map (controller: "-${controller.name}") (
          lib.concatMap (group: group.controllers) (lib.attrValues cfg.groups)
        )
      );
    };

    systemd.services = {
      kube-controller-manager = service "Kubernetes controller manager" cfg.args;
    }
    // lib.mapAttrs' (
      name: group:
      lib.nameValuePair (unitOf name) (service "Kubernetes controller manager (${name})" group.args)
    ) cfg.groups;
  };
}
