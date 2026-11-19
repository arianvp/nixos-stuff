# CoreDNS in pods behind the kube-dns Service. Set the same options on every
# node: nodes with a kubelet load the image and point pods at the Service, nodes
# with an API server apply the manifests.
{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.kubernetes.clusterDNS;
  k8s = config.kubernetes;
  labels."k8s-app" = "kube-dns";
  namespace = "kube-system";
in
{
  options.kubernetes.clusterDNS = {
    enable = lib.mkEnableOption "cluster DNS with CoreDNS";

    serviceIP = lib.mkOption {
      type = lib.types.str;
      description = "Cluster IP of the kube-dns Service, in the service CIDR.";
      example = "fd00:10:96::a";
    };

    upstreams = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "/etc/resolv.conf" ];
      description = ''
        Where to forward queries outside the cluster domain. The default is
        the node's resolv.conf, as configured by the kubelet's `resolvConf`.
      '';
    };

    replicas = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = "Number of CoreDNS pods.";
    };

    image = lib.mkOption {
      type = lib.types.package;
      default = pkgs.dockerTools.buildLayeredImage {
        name = "localhost/coredns";
        tag = pkgs.coredns.version;
        config.Entrypoint = [ (lib.getExe pkgs.coredns) ];
      };
      defaultText = lib.literalExpression "an image of pkgs.coredns";
      description = "CoreDNS image, loaded on every node with a kubelet.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf k8s.kubelet.enable {
        kubernetes.images = [ cfg.image ];
        kubernetes.kubelet.settings.clusterDNS = [ cfg.serviceIP ];
      })

      (lib.mkIf k8s.kube-apiserver.enable {
        kubernetes.addons.manifests = {
          coredns-serviceaccount = {
            apiVersion = "v1";
            kind = "ServiceAccount";
            metadata = {
              name = "coredns";
              inherit namespace;
            };
          };
          coredns-clusterrole = {
            apiVersion = "rbac.authorization.k8s.io/v1";
            kind = "ClusterRole";
            metadata.name = "system:coredns";
            rules = [
              {
                apiGroups = [ "" ];
                resources = [
                  "services"
                  "pods"
                  "namespaces"
                ];
                verbs = [
                  "list"
                  "watch"
                ];
              }
              {
                apiGroups = [ "discovery.k8s.io" ];
                resources = [ "endpointslices" ];
                verbs = [
                  "list"
                  "watch"
                ];
              }
            ];
          };
          coredns-clusterrolebinding = {
            apiVersion = "rbac.authorization.k8s.io/v1";
            kind = "ClusterRoleBinding";
            metadata.name = "system:coredns";
            roleRef = {
              apiGroup = "rbac.authorization.k8s.io";
              kind = "ClusterRole";
              name = "system:coredns";
            };
            subjects = [
              {
                kind = "ServiceAccount";
                name = "coredns";
                inherit namespace;
              }
            ];
          };
          coredns-configmap = {
            apiVersion = "v1";
            kind = "ConfigMap";
            metadata = {
              name = "coredns";
              inherit namespace;
            };
            data.Corefile = ''
              .:53 {
                errors
                health {
                  lameduck 5s
                }
                ready
                kubernetes ${k8s.clusterDomain} in-addr.arpa ip6.arpa {
                  pods insecure
                  fallthrough in-addr.arpa ip6.arpa
                  ttl 30
                }
                prometheus :9153
                forward . ${lib.concatStringsSep " " cfg.upstreams}
                cache 30
                loop
                reload
                loadbalance
              }
            '';
          };
          coredns-deployment = {
            apiVersion = "apps/v1";
            kind = "Deployment";
            metadata = {
              name = "coredns";
              inherit namespace labels;
            };
            spec = {
              inherit (cfg) replicas;
              selector.matchLabels = labels;
              template = {
                metadata = { inherit labels; };
                spec = {
                  serviceAccountName = "coredns";
                  priorityClassName = "system-cluster-critical";
                  dnsPolicy = "Default";
                  topologySpreadConstraints = [
                    {
                      maxSkew = 1;
                      topologyKey = "kubernetes.io/hostname";
                      whenUnsatisfiable = "ScheduleAnyway";
                      labelSelector.matchLabels = labels;
                    }
                  ];
                  containers = [
                    {
                      name = "coredns";
                      image = "${cfg.image.imageName}:${cfg.image.imageTag}";
                      imagePullPolicy = "Never";
                      args = [
                        "-conf"
                        "/etc/coredns/Corefile"
                      ];
                      ports = [
                        {
                          name = "dns";
                          containerPort = 53;
                          protocol = "UDP";
                        }
                        {
                          name = "dns-tcp";
                          containerPort = 53;
                          protocol = "TCP";
                        }
                        {
                          name = "metrics";
                          containerPort = 9153;
                          protocol = "TCP";
                        }
                      ];
                      livenessProbe.httpGet = {
                        path = "/health";
                        port = 8080;
                      };
                      readinessProbe.httpGet = {
                        path = "/ready";
                        port = 8181;
                      };
                      securityContext = {
                        allowPrivilegeEscalation = false;
                        readOnlyRootFilesystem = true;
                        capabilities = {
                          add = [ "NET_BIND_SERVICE" ];
                          drop = [ "ALL" ];
                        };
                      };
                      volumeMounts = [
                        {
                          name = "config";
                          mountPath = "/etc/coredns";
                          readOnly = true;
                        }
                      ];
                    }
                  ];
                  volumes = [
                    {
                      name = "config";
                      configMap.name = "coredns";
                    }
                  ];
                };
              };
            };
          };
          coredns-service = {
            apiVersion = "v1";
            kind = "Service";
            metadata = {
              name = "kube-dns";
              inherit namespace labels;
            };
            spec = {
              selector = labels;
              clusterIP = cfg.serviceIP;
              ports = [
                {
                  name = "dns";
                  port = 53;
                  protocol = "UDP";
                }
                {
                  name = "dns-tcp";
                  port = 53;
                  protocol = "TCP";
                }
                {
                  name = "metrics";
                  port = 9153;
                  protocol = "TCP";
                }
              ];
            };
          };
        };
      })
    ]
  );
}
