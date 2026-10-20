# Encrypts Secrets in etcd with a key in OpenBao's transit secrets engine,
# through the KMS v2 plugin kube-kms-openbao. Set the same options on every
# node: API servers run the plugin, the OpenBao node (spire.openbao) gets the
# transit key and the cert auth role the plugins log in with.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.kubernetes.encryption;
  k8s = config.kubernetes;
  svids = config.spire.svids;
  socket = "/run/kube-kms-openbao/kms.sock";
in
{
  imports = [ ../spire/openbao.nix ];

  options.kubernetes.encryption = {
    enable = lib.mkEnableOption "encrypting resources in etcd with OpenBao";

    package = lib.mkPackageOption pkgs "kube-kms-openbao" { };

    openbao = lib.mkOption {
      type = lib.types.str;
      description = "URL of OpenBao.";
      example = "https://openbao.example.com:8200";
    };

    resources = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "secrets" ];
      description = "Resources to encrypt.";
    };

    transitMount = lib.mkOption {
      type = lib.types.str;
      default = "transit";
      description = "Path of the transit secrets engine.";
    };

    key = lib.mkOption {
      type = lib.types.str;
      default = k8s.clusterName;
      defaultText = lib.literalExpression "config.kubernetes.clusterName";
      description = "Name of the transit key.";
    };

    keyRotationPeriod = lib.mkOption {
      type = lib.types.str;
      default = "720h";
      description = ''
        How often OpenBao rotates the transit key. The API servers notice
        within a minute and encrypt new writes with the new version.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf k8s.kube-apiserver.enable {

        # The plugin rereads its SVID on every connection, so it needs no
        # restarts
        spire.svids.kube-kms-openbao = { };
        kubernetes.spire.entries."${config.networking.hostName}-kube-kms-openbao" = {
          spiffeID = "spiffe://${k8s.spire.trustDomain}/k8s/kms/${config.networking.hostName}";
          selectors = [ "systemd:id:${svids.kube-kms-openbao.unit}" ];
        };

        systemd.services.kube-kms-openbao = {
          description = "Kubernetes KMS plugin for OpenBao";
          wantedBy = [ "kube-apiserver.service" ];
          before = [ "kube-apiserver.service" ];
          requires = [ svids.kube-kms-openbao.unit ];
          after = [ svids.kube-kms-openbao.unit ];
          serviceConfig = {
            Type = "notify";
            ExecStart = lib.escapeShellArgs [
              (lib.getExe cfg.package)
              "-socket"
              socket
              "-address"
              cfg.openbao
              "-transit-mount"
              cfg.transitMount
              "-key"
              cfg.key
              "-role"
              "kubernetes-kms"
              "-cert-file"
              svids.kube-kms-openbao.paths.cert
              "-key-file"
              svids.kube-kms-openbao.paths.key
              "-ca-file"
              svids.kube-kms-openbao.paths.bundle
            ];
            Restart = "on-failure";
            RestartSec = "5s";
            RuntimeDirectory = "kube-kms-openbao";
            UMask = "0077";
          };
        };

        kubernetes.kube-apiserver.encryptionConfig.resources = [
          {
            inherit (cfg) resources;
            providers = [
              {
                kms = {
                  apiVersion = "v2";
                  name = "openbao";
                  endpoint = "unix://${socket}";
                  timeout = "5s";
                };
              }
              # Reads what was written before encryption was enabled
              { identity = { }; }
            ];
          }
        ];
      })

      (lib.mkIf config.spire.openbao.enable {
        spire.openbao = {
          policies.kubernetes-kms = ''
            path "${cfg.transitMount}/encrypt/${cfg.key}" {
              capabilities = ["update"]
            }
            path "${cfg.transitMount}/decrypt/${cfg.key}" {
              capabilities = ["update"]
            }
            path "${cfg.transitMount}/keys/${cfg.key}" {
              capabilities = ["read"]
            }
          '';
          certRoles.kubernetes-kms = {
            allowedURISANs = [ "spiffe://${k8s.spire.trustDomain}/k8s/kms/*" ];
            policies = [ "kubernetes-kms" ];
          };
          initialize = [
            {
              operation = "update";
              path = "sys/mounts/${cfg.transitMount}";
              data.type = "transit";
            }
            {
              operation = "update";
              path = "${cfg.transitMount}/keys/${cfg.key}";
              data = {
                type = "aes256-gcm96";
                auto_rotate_period = cfg.keyRotationPeriod;
              };
            }
          ];
        };
      })
    ]
  );
}
