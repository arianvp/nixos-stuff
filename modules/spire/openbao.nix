# OpenBao that bootstraps itself and authenticates clients by their X509-SVID.
#
# * It serves TLS with an X509-SVID, which it reloads when renewed.
# * It unseals itself with a static key, from a (possibly encrypted) systemd
#   credential.
# * It initializes itself on first start: it enables cert auth and lets the
#   SVIDs of its nodes manage policies and cert auth roles. The root token is
#   revoked. In a raft cluster, one node bootstraps and the others join it.
#   The bootstrap node joins too when another node is already initialized,
#   e.g. after it lost its disk.
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
  nodeIDApp = "40fd988b-8b05-43c3-b67a-bfb3963a3659";

  # Requests run in order, but Nix sorts the keys of objects, so they go in
  # lists
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
  ++ lib.optional (requests != [ ]) {
    extra.request = lib.imap1 (i: request: {
      "request-${toString i}" = request;
    }) requests;
  };

  # Self-init is a no-op on initialized storage, so this needn't look at the
  # local storage. That also covers a restart before a join completed.
  initializeFile = "/run/openbao/initialize.json";
  initializeOrJoin = pkgs.writeShellApplication {
    name = "openbao-initialize-or-join";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      peers=(${lib.escapeShellArgs cfg.retryJoin})
      for peer in "''${peers[@]}"; do
        if curl --silent --show-error --fail --connect-timeout 3 --max-time 5 \
          --cacert ${svid.paths.bundle} "$peer/v1/sys/init" | jq -e .initialized > /dev/null; then
          echo "$peer is initialized, joining its cluster"
          echo '{}' > ${initializeFile}
          exit 0
        fi
      done
      echo "No node to join is initialized, initializing the cluster unless already done"
      cat ${format.generate "openbao-initialize.json" { inherit initialize; }} > ${initializeFile}
    '';
  };

  # The engines first, as the requests that follow configure what is in them
  requests =
    lib.mapAttrsToList (path: engine: {
      operation = "update";
      path = "sys/mounts/${path}";
      data = { inherit (engine) type; };
    }) cfg.secretEngines
    ++ cfg.initialize;

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

    managers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ cfg.spiffeID ];
      defaultText = lib.literalExpression "[ config.spire.openbao.spiffeID ]";
      description = ''
        SPIFFE IDs that manage policies and cert auth roles: those of all
        nodes of the cluster.
      '';
    };

    bootstrap = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether this node initializes the cluster. Exactly one node of a cluster
        does; the others join it with {option}`retryJoin`. Before it starts,
        it asks the nodes of {option}`retryJoin` whether they are initialized.
        If one is, it joins them like the others, so that a bootstrap node
        that lost its storage doesn't initialize a second cluster. A bootstrap
        node with empty storage that reaches none of them, e.g. because they
        are down, still initializes a new cluster.
      '';
    };

    nodeID = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Raft node ID, unique in the cluster. By default it is the host name
        followed by the first 12 hex digits of an app-specific hash of the
        machine ID, e.g. `openbao1-3f2a9c1e04bd`, which OpenBao gets from
        `BAO_RAFT_NODE_ID` on every start. A node that loses
        {file}`/var/lib/openbao` keeps its ID and takes the place of its old
        raft peer, while a reinstalled machine, with a new machine ID, joins
        as a new member. The hash keeps the machine ID itself out of the raft
        configuration and snapshots.

        A string sets `storage.raft.node_id` instead. A node whose ID changes
        is no longer the same raft member, so on a node that joined with a
        random ID, which OpenBao picks when none is set, set this to the
        contents of its {file}`/var/lib/openbao/node-id`.
      '';
    };

    retryJoin = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "API addresses of the nodes to join the raft cluster of.";
      example = [ "https://openbao1.example.com:8200" ];
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8200;
      description = "Port of the API.";
    };

    sealKey = {
      file = lib.mkOption {
        type = lib.types.str;
        example = "/var/lib/secrets/openbao-seal-key";
        description = ''
          File holding the 32 byte AES key OpenBao unseals itself with: raw, hex
          or base64 encoded. A path on the node, as a path in the Nix store
          would put the key where every user can read it unless
          {option}`encrypted` is set.
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

    secretEngines = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options.type = lib.mkOption {
            type = lib.types.str;
            description = "Type of the secrets engine.";
          };
        }
      );
      default = { };
      description = ''
        Secrets engines to mount, by the path they are mounted at. Several
        modules may ask for the same one, as long as they agree on its type.
      '';
      example = {
        transit.type = "transit";
      };
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
        Requests made once, when the {option}`bootstrap` node initializes the
        cluster, after mounting {option}`secretEngines`. See
        <https://openbao.org/docs/configuration/self-init/>.
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
      allowedURISANs = cfg.managers;
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
        storage.raft = {
          path = "/var/lib/openbao";
        }
        // lib.optionalAttrs (cfg.nodeID != null) {
          node_id = cfg.nodeID;
        }
        # OpenBao rejects an empty retry_join, so only join when asked to
        // lib.optionalAttrs (cfg.retryJoin != [ ]) {
          retry_join = map (address: {
            leader_api_addr = address;
            leader_ca_cert_file = svid.paths.bundle;
          }) cfg.retryJoin;
        };
        seal.static = {
          current_key_id = cfg.sealKey.id;
          current_key = "file:///run/credentials/openbao.service/seal-key";
        };
      };
    };

    systemd.services.openbao-node-id = lib.mkIf (cfg.nodeID == null) {
      description = "Derive the OpenBao raft node ID from the machine ID";
      requiredBy = [ "openbao.service" ];
      before = [ "openbao.service" ];
      # Restarting it would restart OpenBao, which has restartIfChanged = false
      restartIfChanged = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "openbao-node-id";
      };
      script = ''
        id=$(${config.systemd.package}/bin/systemd-id128 machine-id --app-specific=${nodeIDApp})
        echo "BAO_RAFT_NODE_ID=${config.networking.hostName}-''${id:0:12}" > "$RUNTIME_DIRECTORY/env"
      '';
    };

    services.openbao.extraArgs = lib.mkIf cfg.bootstrap [
      "-config"
      initializeFile
    ];

    systemd.services.openbao = {
      requires = [ svid.unit ];
      after = [ svid.unit ];
      serviceConfig = {
        EnvironmentFile = lib.mkIf (cfg.nodeID == null) "/run/openbao-node-id/env";
        ExecStartPre = lib.mkIf cfg.bootstrap (lib.getExe initializeOrJoin);
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
