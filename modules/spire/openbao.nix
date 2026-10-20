# OpenBao that bootstraps itself and authenticates clients by their X509-SVID.
#
# * It serves TLS with an X509-SVID, which it reloads when renewed.
# * It unseals itself with a static key, from a (possibly encrypted) systemd
#   credential.
# * It initializes itself on first start: it enables cert auth and lets its own
#   SVID manage policies and cert auth roles. The root token is revoked.
# * openbao-config.service applies policies and cert auth roles on every
#   start, configuration change and whenever a CA is added to the trust
#   bundle, so that cert auth trusts the current CAs of the trust domain.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.spire.openbao;
  svid = config.spire.svids.openbao;
  format = pkgs.formats.json { };
  address = "https://${cfg.dnsName}:${toString cfg.port}";

  # OpenBao reads HCL1, whose JSON form turns every key of an object in a list
  # into a block of its own, and Nix sorts the keys of objects. Lists of
  # single-key objects keep the requests apart and in order.
  initialize = [
    {
      spire.request = [
        {
          openbao-config-policy = {
            operation = "update";
            path = "sys/policies/acl/openbao-config";
            data.policy = configPolicy;
          };
        }
        {
          cert-auth = {
            operation = "update";
            path = "sys/auth/cert";
            data.type = "cert";
          };
        }
        {
          openbao-config-role = {
            operation = "update";
            path = "auth/cert/certs/openbao-config";
            data = roleData cfg.certRoles.openbao-config // {
              certificate = {
                eval_type = "string";
                eval_source = "file";
                path = svid.paths.bundle;
              };
            };
          };
        }
      ];
    }
  ]
  ++ lib.optional (cfg.initialize != [ ]) {
    extra.request = lib.imap1 (i: request: { "request-${toString i}" = request; }) cfg.initialize;
  };

  configPolicy = ''
    path "sys/policies/acl/*" {
      capabilities = ["create", "update", "read"]
    }
    path "auth/cert/certs/*" {
      capabilities = ["create", "update", "read"]
    }
  '';

  roleData = role: {
    allowed_uri_sans = role.allowedURISANs;
    token_policies = role.policies;
    token_ttl = role.tokenTTL;
  };

  desiredState = format.generate "openbao-config.json" {
    policies = cfg.policies;
    roles = lib.mapAttrs (_: roleData) cfg.certRoles;
  };

  roleModule = {
    options = {
      allowedURISANs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "SPIFFE IDs (globs allowed) that may log in with this role.";
        example = [ "spiffe://example.org/k8s/kms/*" ];
      };
      policies = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Policies of the tokens issued for this role.";
      };
      tokenTTL = lib.mkOption {
        type = lib.types.str;
        default = "1h";
        description = "Lifetime of the tokens issued for this role.";
      };
    };
  };
in
{
  imports = [ ./svid.nix ];

  options.spire.openbao = {
    enable = lib.mkEnableOption "OpenBao bootstrapped from SPIRE";

    spiffeID = lib.mkOption {
      type = lib.types.str;
      description = ''
        SPIFFE ID of OpenBao's X509-SVID, whose registration entry selects
        `systemd:id:openbao-svid.service`. It manages policies and cert auth
        roles.
      '';
      example = "spiffe://example.org/openbao/node1";
    };

    dnsName = lib.mkOption {
      type = lib.types.str;
      default = config.networking.fqdnOrHostName;
      defaultText = lib.literalExpression "config.networking.fqdnOrHostName";
      description = "DNS name of OpenBao, which its X509-SVID must carry.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8200;
      description = "Port of the API.";
    };

    sealKey = {
      file = lib.mkOption {
        type = lib.types.path;
        description = ''
          File holding the 32 byte AES key OpenBao unseals itself with: raw, hex
          or base64 encoded.
        '';
      };
      encrypted = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether {option}`sealKey.file` is encrypted with
          {command}`systemd-creds encrypt`, e.g. with the TPM.
        '';
      };
      id = lib.mkOption {
        type = lib.types.str;
        default = "1";
        description = "Identifier of the seal key, to change when replacing it.";
      };
    };

    policies = lib.mkOption {
      type = lib.types.attrsOf lib.types.lines;
      default = { };
      description = "ACL policies, by name.";
      example = {
        kms = ''
          path "transit/encrypt/kubernetes" {
            capabilities = ["update"]
          }
        '';
      };
    };

    certRoles = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule roleModule);
      default = { };
      description = ''
        Cert auth roles, by name. They trust the CAs of the trust bundle and
        match clients by the SPIFFE ID of their X509-SVID. OpenBao names
        identity aliases after the subject CN, so client SVIDs need one: a DNS
        name, or a CN set by spire-credentialcomposer-x509.
      '';
    };

    initialize = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            operation = lib.mkOption {
              type = lib.types.enum [
                "create"
                "read"
                "update"
                "delete"
                "list"
              ];
              description = "Operation of the request.";
            };
            path = lib.mkOption {
              type = lib.types.str;
              description = "API path of the request.";
            };
            data = lib.mkOption {
              type = format.type;
              default = { };
              description = "Parameters of the request.";
            };
          };
        }
      );
      default = [ ];
      description = ''
        Requests made once, when OpenBao initializes, e.g. to enable secrets
        engines. See <https://openbao.org/docs/configuration/self-init/>.
      '';
      example = lib.literalExpression ''
        [
          {
            operation = "update";
            path = "sys/mounts/transit";
            data.type = "transit";
          }
        ]
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    spire.openbao.certRoles.openbao-config = {
      allowedURISANs = [ cfg.spiffeID ];
      policies = [ "openbao-config" ];
      tokenTTL = "5m";
    };
    spire.openbao.policies.openbao-config = configPolicy;

    users.groups.openbao-svid = { };
    spire.svids.openbao = {
      group = "openbao-svid";
      reloadOnRenewal = [ "openbao.service" ];
      restartOnBundleChange = [ "openbao-config.service" ];
    };

    services.openbao = {
      enable = true;
      settings = {
        api_addr = address;
        cluster_addr = "https://${cfg.dnsName}:${toString (cfg.port + 1)}";
        listener.default = {
          type = "tcp";
          address = "[::]:${toString cfg.port}";
          cluster_address = "[::]:${toString (cfg.port + 1)}";
          tls_cert_file = svid.paths.cert;
          tls_key_file = svid.paths.key;
        };
        inherit initialize;
        storage.raft.path = "/var/lib/openbao";
        seal.static = {
          current_key_id = cfg.sealKey.id;
          current_key = "file:///run/credentials/openbao.service/seal-key";
        };
      };
    };

    systemd.services.openbao = {
      requires = [ svid.unit ];
      after = [ svid.unit ];
      serviceConfig = {
        SupplementaryGroups = [ "openbao-svid" ];
        ${if cfg.sealKey.encrypted then "LoadCredentialEncrypted" else "LoadCredential"} =
          "seal-key:${cfg.sealKey.file}";
      };
    };

    networking.firewall.allowedTCPPorts = [
      cfg.port
      (cfg.port + 1)
    ];

    systemd.services.openbao-config = {
      description = "Apply OpenBao policies and cert auth roles";
      wantedBy = [ "multi-user.target" ];
      wants = [ "openbao.service" ];
      after = [ "openbao.service" ];
      restartTriggers = [ desiredState ];
      # Keeps retrying while OpenBao comes up
      startLimitIntervalSec = 0;
      path = [
        pkgs.curl
        pkgs.jq
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "5s";
      };
      script = ''
        bao() {
          curl --silent --show-error --fail-with-body \
            --cacert ${svid.paths.bundle} --cert ${svid.paths.cert} --key ${svid.paths.key} \
            "$@"
        }
        token=$(bao --data '{"name": "openbao-config"}' ${address}/v1/auth/cert/login | jq -r .auth.client_token)

        jq -c '.policies | to_entries[]' ${desiredState} | while read -r policy; do
          jq '{policy: .value}' <<< "$policy" |
            bao -H "X-Vault-Token: $token" --data @- \
              "${address}/v1/sys/policies/acl/$(jq -r .key <<< "$policy")"
        done

        jq -c '.roles | to_entries[]' ${desiredState} | while read -r role; do
          jq --rawfile certificate ${svid.paths.bundle} '.value + {certificate: $certificate}' <<< "$role" |
            bao -H "X-Vault-Token: $token" --data @- \
              "${address}/v1/auth/cert/certs/$(jq -r .key <<< "$role")"
        done
      '';
    };
  };
}
