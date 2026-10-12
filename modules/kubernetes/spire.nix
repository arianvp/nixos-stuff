# Bootstraps a cluster from SPIRE: every component authenticates with an
# X509-SVID from the SPIFFE Workload API and trusts the SPIRE trust bundle,
# so there is no Kubernetes PKI to manage.
#
# The SPIRE server needs kubernetes.spire.server, which composes the subjects
# Kubernetes reads users and groups from, and the IP SANs pods reach the API
# server by.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.kubernetes.spire;
  k8s = config.kubernetes;
  svids = config.spire.svids;
  hostName = config.networking.hostName;
  fqdn = config.networking.fqdnOrHostName;
  domainSuffix = lib.optionalString (config.networking.domain != null) ".${config.networking.domain}";

  spiffeID = path: "spiffe://${cfg.trustDomain}/${path}";

  execAuth = pkgs.writeShellApplication {
    name = "k8s-spiffe-exec-auth";
    runtimeInputs = [
      pkgs.spire.agent
      pkgs.jq
      pkgs.openssl
      pkgs.coreutils
    ];
    text = ''
      dir=$(mktemp -d)
      trap 'rm -rf "$dir"' EXIT
      # It prints to stdout even with -silent
      spire-agent api fetch x509 -socketPath "''${SPIFFE_ENDPOINT_SOCKET:?}" -write "$dir" > /dev/null
      expiry=$(openssl x509 -in "$dir/svid.0.pem" -noout -enddate | cut -d= -f2)
      jq --null-input \
        --rawfile cert "$dir/svid.0.pem" \
        --rawfile key "$dir/svid.0.key" \
        --arg expiry "$(date --utc --date "$expiry" +%Y-%m-%dT%H:%M:%SZ)" \
        '{
          apiVersion: "client.authentication.k8s.io/v1",
          kind: "ExecCredential",
          status: {clientCertificateData: $cert, clientKeyData: $key, expirationTimestamp: $expiry}
        }'
    '';
  };

  # Kubeconfig for a daemon whose SVID spiffe-helper keeps on disk
  svidKubeconfig = svid: {
    clusterMap.${k8s.clusterName} = {
      server = cfg.apiServer;
      certificate-authority = svid.paths.bundle;
    };
    userMap.default = {
      client-certificate = svid.paths.cert;
      client-key = svid.paths.key;
    };
    contextMap.default = {
      cluster = k8s.clusterName;
      user = "default";
    };
    settings.current-context = "default";
  };

  # An SVID for a unit, which the unit waits for. etcd, the API server's
  # clients of etcd and the kubelets, and client-go in the kubelet and
  # kube-proxy read their CA files only on startup, so the unit restarts when a
  # CA is added to the trust bundle.
  svidFor = unit: {
    spire.svids.${unit} = {
      restartOnBundleChange = [ "${unit}.service" ];
      restartMaxDelaySec = cfg.restartMaxDelaySec;
    };
    systemd.services.${unit} = {
      requires = [ svids.${unit}.unit ];
      after = [ svids.${unit}.unit ];
    };
  };

  entry = name: path: extra: {
    kubernetes.spire.entries."${hostName}-${name}" = {
      spiffeID = spiffeID path;
      selectors = [ "systemd:id:${svids.${name}.unit}" ];
    }
    // extra;
  };

  entryModule = {
    options = {
      spiffeID = lib.mkOption {
        type = lib.types.str;
        description = "SPIFFE ID of the workload.";
      };
      parentID = lib.mkOption {
        type = lib.types.str;
        default = cfg.parentID;
        defaultText = lib.literalExpression "config.kubernetes.spire.parentID";
        description = "SPIFFE ID of the agent the workload runs under.";
      };
      selectors = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Workload selectors.";
      };
      dnsNames = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "DNS names for the X509-SVID.";
      };
      ipAddresses = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "IP addresses for the X509-SVID, which kubernetes.spire.server adds.";
      };
    };
  };
in
{
  imports = [
    ../spire/svid.nix
    ./spire-server.nix
  ];

  options.kubernetes.spire = {
    enable = lib.mkEnableOption "bootstrapping the enabled Kubernetes components from SPIRE";

    trustDomain = lib.mkOption {
      type = lib.types.str;
      default = config.services.spire.agent.settings.agent.trust_domain;
      defaultText = lib.literalExpression "config.services.spire.agent.settings.agent.trust_domain";
      description = "SPIFFE trust domain of the cluster.";
    };

    parentID = lib.mkOption {
      type = lib.types.str;
      description = "SPIFFE ID of this node's SPIRE agent.";
      example = "spiffe://example.com/spire/agent/http_challenge/node1";
    };

    apiServer = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        URL of the API server. Required for components that talk to it. With
        several API servers, use a name that resolves to all of them and add it
        to {option}`apiServerDNSNames`: clients try the addresses in turn.
      '';
      example = "https://control.example.com:6443";
    };

    apiServerDNSNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra DNS names for the API server's serving certificate.";
    };

    restartMaxDelaySec = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 600;
      description = ''
        Upper bound of the random delay before components restart for a new
        CA in the trust bundle, so that the cluster does not restart at once.
        It must be shorter than the time between SPIRE preparing and
        activating a CA: a third of SPIRE's `ca_ttl`, which defaults to a day.
      '';
    };

    controlPlane = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Host names of all nodes running an API server. Their service account
        token signers trust each other's keys.
      '';
    };

    admins = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      description = ''
        Workload selectors, per admin name, of processes on this node that are
        cluster admins. They authenticate with the kubeconfig in
        {env}`KUBECONFIG`.
      '';
      example = {
        arian = [ "unix:uid:1000" ];
      };
    };

    entries = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule entryModule);
      default = { };
      description = ''
        Registration entries for the workloads on this node, for
        {option}`kubernetes.spire.server.entries`.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion =
              cfg.apiServer != null
              || !(k8s.kubelet.enable || k8s.kube-proxy.enable || k8s.kube-scheduler.enable);
            message = "kubernetes.spire.apiServer must be set on nodes that run components talking to the API server.";
          }
        ];

        kubernetes.spire.entries = lib.mapAttrs' (
          name: selectors:
          lib.nameValuePair "${hostName}-admin-${name}" {
            spiffeID = spiffeID "k8s/admin/${name}";
            inherit selectors;
          }
        ) cfg.admins;
      }

      # kubectl authenticates as the SPIFFE ID of whoever runs it
      (lib.mkIf (cfg.apiServer != null) (
        lib.mkMerge [
          (entry "trust-bundle" "k8s/trust-bundle/${hostName}" { })
          {
            # Only for its bundle, which everyone may read
            spire.svids.trust-bundle.directoryMode = "0755";

            environment.systemPackages = [
              execAuth
              pkgs.kubectl
            ];

            kubernetes.kubeconfigs.spiffe = {
              clusterMap.${k8s.clusterName} = {
                server = cfg.apiServer;
                certificate-authority = svids.trust-bundle.paths.bundle;
              };
              userMap.default.exec = {
                command = lib.getExe execAuth;
                env = [
                  {
                    name = "SPIFFE_ENDPOINT_SOCKET";
                    value = config.services.spire.agent.settings.agent.socket_path;
                  }
                ];
                interactiveMode = "Never";
              };
              contextMap.default = {
                cluster = k8s.clusterName;
                user = "default";
              };
              settings.current-context = "default";
            };
            environment.variables.KUBECONFIG = lib.mkDefault "${k8s.kubeconfigs.spiffe.file}";
          }
        ]
      ))

      (lib.mkIf k8s.etcd.enable (
        lib.mkMerge [
          (svidFor "etcd")
          (entry "etcd" "k8s/etcd/${hostName}" {
            dnsNames = [
              "etcd-peer"
              fqdn
              hostName
            ];
          })
          {
            kubernetes.etcd.settings =
              let
                tls = {
                  cert-file = svids.etcd.paths.cert;
                  key-file = svids.etcd.paths.key;
                  trusted-ca-file = svids.etcd.paths.bundle;
                  client-cert-auth = true;
                };
              in
              {
                listen-client-urls = lib.mkDefault "https://[::]:2379";
                advertise-client-urls = lib.mkDefault "https://${fqdn}:2379";
                listen-peer-urls = lib.mkDefault "https://[::]:2380";
                initial-advertise-peer-urls = lib.mkDefault "https://${fqdn}:2380";
                initial-cluster = lib.mkDefault "${hostName}=https://${fqdn}:2380";
                # Any SVID chains to the trust bundle, so restrict who may connect
                client-transport-security = tls // {
                  allowed-hostname = [ "kube-apiserver" ];
                };
                peer-transport-security = tls // {
                  allowed-hostname = [ "etcd-peer" ];
                };
                # The gateway dials etcd with InsecureSkipVerify but keeps the
                # server's allowed-hostname check, so it can never connect.
                enable-grpc-gateway = false;
              };
            networking.firewall.allowedTCPPorts = [
              2379
              2380
            ];
          }
        ]
      ))

      (lib.mkIf k8s.kube-apiserver.enable (
        let
          advertiseAddress = k8s.kube-apiserver.args.advertise-address or null;
        in
        lib.mkMerge [
          (svidFor "kube-apiserver")
          (entry "kube-apiserver" "k8s/kube-apiserver/${hostName}" {
            # etcd allows clients by this name
            dnsNames = [
              "kube-apiserver"
              fqdn
              hostName
              "kubernetes"
              "kubernetes.default"
              "kubernetes.default.svc"
              "kubernetes.default.svc.${k8s.clusterDomain}"
            ]
            ++ cfg.apiServerDNSNames;
            # Pods connect to the kubernetes Service by IP
            ipAddresses = [
              k8s.apiServerServiceIP
            ]
            ++ lib.optional (advertiseAddress != null) advertiseAddress;
          })
          {

            kubernetes.spire.apiServer = lib.mkDefault "https://${fqdn}:6443";

            kubernetes.kube-apiserver.args = {
              etcd-servers = lib.mkIf k8s.etcd.enable (lib.mkDefault [ "https://${fqdn}:2379" ]);
              etcd-cafile = svids.kube-apiserver.paths.bundle;
              etcd-certfile = svids.kube-apiserver.paths.cert;
              etcd-keyfile = svids.kube-apiserver.paths.key;

              tls-cert-file = svids.kube-apiserver.paths.cert;
              tls-private-key-file = svids.kube-apiserver.paths.key;
              client-ca-file = svids.kube-apiserver.paths.bundle;

              kubelet-certificate-authority = svids.kube-apiserver.paths.bundle;
              kubelet-client-certificate = svids.kube-apiserver.paths.cert;
              kubelet-client-key = svids.kube-apiserver.paths.key;

              authorization-mode = lib.mkDefault [
                "Node"
                "RBAC"
              ];
              enable-admission-plugins = lib.mkDefault [ "NodeRestriction" ];
              service-account-issuer = lib.mkDefault "https://kubernetes.default.svc.${k8s.clusterDomain}";
            };

            kubernetes.kube-jwt-signer = {
              enable = true;
              peers = map (host: {
                spiffeID = spiffeID "k8s/kube-jwt-signer/${host}";
                url = "https://${host}${domainSuffix}:${toString k8s.kube-jwt-signer.port}";
              }) (lib.remove hostName cfg.controlPlane);
            };
            kubernetes.spire.entries."${hostName}-kube-jwt-signer" = {
              spiffeID = spiffeID "k8s/kube-jwt-signer/${hostName}";
              selectors = [ "systemd:id:kube-jwt-signer.service" ];
            };

            networking.firewall.allowedTCPPorts = [ 6443 ];

            kubernetes.addons.kubeconfig = "${k8s.kubeconfigs.kube-addons.file}";
            kubernetes.addons.manifests.kube-apiserver-kubelet-api-admin = {
              apiVersion = "rbac.authorization.k8s.io/v1";
              kind = "ClusterRoleBinding";
              metadata.name = "kube-apiserver:kubelet-api-admin";
              roleRef = {
                apiGroup = "rbac.authorization.k8s.io";
                kind = "ClusterRole";
                name = "system:kubelet-api-admin";
              };
              subjects = [
                {
                  apiGroup = "rbac.authorization.k8s.io";
                  kind = "User";
                  name = "kube-apiserver";
                }
              ];
            };
          }
        ]
      ))

      (lib.mkIf (k8s.addons.manifests != { }) (
        lib.mkMerge [
          (svidFor "kube-addons")
          (entry "kube-addons" "k8s/admin/kube-addons" { })
          { kubernetes.kubeconfigs.kube-addons = svidKubeconfig svids.kube-addons; }
        ]
      ))

      (lib.mkIf k8s.kube-controller-manager.enable (
        lib.mkMerge [
          (svidFor "kube-controller-manager")
          (entry "kube-controller-manager" "k8s/system/kube-controller-manager" { })
          {
            kubernetes.kubeconfigs.kube-controller-manager = svidKubeconfig svids.kube-controller-manager;
            kubernetes.kube-controller-manager.args =
              let
                kubeconfig = "${k8s.kubeconfigs.kube-controller-manager.file}";
              in
              {
                inherit kubeconfig;
                authentication-kubeconfig = kubeconfig;
                authorization-kubeconfig = kubeconfig;
                cluster-name = k8s.clusterName;
                root-ca-file = svids.kube-controller-manager.paths.bundle;
                use-service-account-credentials = true;
              };
          }
        ]
      ))

      (lib.mkIf k8s.kube-scheduler.enable (
        lib.mkMerge [
          (svidFor "kube-scheduler")
          (entry "kube-scheduler" "k8s/system/kube-scheduler" { })
          {
            kubernetes.kubeconfigs.kube-scheduler = svidKubeconfig svids.kube-scheduler;
            kubernetes.kube-scheduler.settings.clientConnection.kubeconfig =
              "${k8s.kubeconfigs.kube-scheduler.file}";
            kubernetes.kube-scheduler.args = {
              authentication-kubeconfig = "${k8s.kubeconfigs.kube-scheduler.file}";
              authorization-kubeconfig = "${k8s.kubeconfigs.kube-scheduler.file}";
            };
          }
        ]
      ))

      (lib.mkIf k8s.kubelet.enable (
        lib.mkMerge [
          (svidFor "kubelet")
          (entry "kubelet" "k8s/node/${hostName}" {
            dnsNames = [
              fqdn
              hostName
            ];
          })
          {
            kubernetes.kubeconfigs.kubelet = svidKubeconfig svids.kubelet;
            kubernetes.kubelet = {
              kubeconfig = "${k8s.kubeconfigs.kubelet.file}";
              # The node name has to match the SPIFFE ID for the Node authorizer
              args.hostname-override = hostName;
              settings = {
                tlsCertFile = svids.kubelet.paths.cert;
                tlsPrivateKeyFile = svids.kubelet.paths.key;
                authentication = {
                  anonymous.enabled = false;
                  webhook.enabled = true;
                  x509.clientCAFile = svids.kubelet.paths.bundle;
                };
                authorization.mode = "Webhook";
              };
            };
            networking.firewall.allowedTCPPorts = [ 10250 ];
          }
        ]
      ))

      (lib.mkIf k8s.kube-proxy.enable (
        lib.mkMerge [
          (svidFor "kube-proxy")
          (entry "kube-proxy" "k8s/system/kube-proxy" { })
          {
            kubernetes.kubeconfigs.kube-proxy = svidKubeconfig svids.kube-proxy;
            kubernetes.kube-proxy.settings = {
              clientConnection.kubeconfig = "${k8s.kubeconfigs.kube-proxy.file}";
              hostnameOverride = hostName;
            };
          }
        ]
      ))
    ]
  );
}
