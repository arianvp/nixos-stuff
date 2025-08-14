{ pkgs, lib, ... }:
let
  trustDomain = "example.com";
in
{
  name = "spire";

  interactive.sshBackdoor.enable = true;

  defaults = {
    imports = [
      ../modules/spire/agent.nix
      ./agent.nix
    ];
    networking.domain = trustDomain;
    spire.agent.trustDomain = trustDomain;
    spire.agent.serverAddress = "server.${trustDomain}";
  };

  nodes = {
    openbao =
      { config, ... }:
      {

        networking.firewall.allowedTCPPorts = [ 8200 ];

        virtualisation.forwardPorts = [
          {
            from = "host";
            host.port = 8200;
            guest.port = 8200;
          }
        ];

        systemd.services.openbao.serviceConfig.ExecStartPre =
          "${lib.getExe' pkgs.spire "spire-agent"} api fetch x509 -socketPath /run/spire-agent/public/api.sock -write $RUNTIME_DIRECTORY";

        services.openbao = {
          enable = true;
          settings = {
            ui = true;
            listener = {
              default = {
                type = "tcp";
                tls_cert_file = "/run/openbao/svid.0.pem";
                tls_key_file = "/run/openbao/svid.0.key";
                address = "[::]:8200";
                cluster_address = "[::]:8201";
              };
            };
            api_addr = "https://openbao.${trustDomain}:8200";
            cluster_addr = "https://openbao.${trustDomain}:8201";
            storage.raft.path = "/var/lib/openbao";

          };
        };

        environment.variables = {
          VAULT_ADDR = config.services.openbao.settings.api_addr;
          VAULT_FORMAT = "json";
          VAULT_CACERT = "/run/openbao/bundle.0.pem";
          VAULT_CLIENT_CERT = "/run/openbao/svid.0.pem";
          VAULT_CLIENT_KEY = "/run/openbao/svid.0.key";
        };
      };

    server = {
      imports = [
        ../modules/spire/server.nix
        ../modules/spire/controller-manager.nix
      ];
      spire.controllerManager.enable = true;
      spire.controllerManager.manifests = [
        {
          apiVersion = "spire.spiffe.io/v1alpha1";
          kind = "ClusterStaticEntry";
          metadata = {
            name = "openbao";
          };
          spec = {
            selectors = [ "systemd:id:openbao.service" ];
            parentID = "spiffe://${trustDomain}/server/openbao";
            spiffeID = "spiffe://${trustDomain}/service/openbao";
            dnsNames = [ "openbao.${trustDomain}" ];
          };
        }
        {

          apiVersion = "spire.spiffe.io/v1alpha1";
          kind = "ClusterStaticEntry";
          metadata = {
            name = "root";
          };
          spec = {
            selectors = [ "unix:uid:0" ];
            parentID = "spiffe://${trustDomain}/server/agent";
            spiffeID = "spiffe://${trustDomain}/service/agent";
            dnsNames = [ "agent.${trustDomain}" ];
          };
        }
        {
          apiVersion = "spire.spiffe.io/v1alpha1";
          kind = "ClusterStaticEntry";
          metadata = {
            name = "admin";
          };
          spec = {
            selectors = [ "unix:uid:0" ];
            parentID = "spiffe://${trustDomain}/server/openbao";
            spiffeID = "spiffe://${trustDomain}/user/admin";
            dnsNames = [ "admin.openboa.${trustDomain}" ]; # https://github.com/hashicorp/vault/issues/6820
          };
        }
      ];
      spire.server = {
        enable = true;
        inherit trustDomain;
        config = ''
          plugins {
            KeyManager "memory" {
              plugin_data {
              }
            }
            DataStore "sql" {
              plugin_data {
                database_type = "sqlite3"
                connection_string = "$STATE_DIRECTORY/datastore.sqlite3"
              }
            }
            NodeAttestor "join_token" {
              plugin_data {
              }
            }
          }
        '';
      };
    };

    agent = {
      environment.systemPackages = [ pkgs.openbao ];
      environment.variables = {
        VAULT_ADDR = "https://openbao.${trustDomain}:8200";
        VAULT_FORMAT = "json";
      };
    };
  };

  testScript = ''
    server.wait_for_unit("spire-server.socket")
    server.wait_for_unit("spire-server-local.socket")

    server.succeed("spire-server healthcheck -socketPath /run/spire-server/private/api.sock")
    server.succeed("curl -kv https://server:8081")

    server.wait_for_unit("spire-controller-manager.service")

    bundle = server.succeed("spire-server bundle show -socketPath /run/spire-server/private/api.sock")
    with open("bundle.pem", "w") as f:
        f.write(bundle)

    token = server.succeed("spire-server token generate -socketPath /run/spire-server/private/api.sock -spiffeID spiffe://example.com/server/agent").split()[1]
    with open("spire-join-token", "w") as f:
        f.write(f"SPIRE_AGENT_JOIN_TOKEN={token}")

    agent.copy_from_host("bundle.pem", "/run/credstore/spire-server-bundle")
    agent.copy_from_host("spire-join-token", "/run/credstore/spire-server-join-token")
    agent.wait_for_unit("spire-agent.socket")
    agent.succeed("spire-agent healthcheck -socketPath /run/spire-agent/public/api.sock")


    token = server.succeed("spire-server token generate -socketPath /run/spire-server/private/api.sock -spiffeID spiffe://example.com/server/openbao").split()[1]
    with open("spire-join-token", "w") as f:
        f.write(f"SPIRE_AGENT_JOIN_TOKEN={token}")
    openbao.copy_from_host("bundle.pem", "/run/credstore/spire-server-bundle")
    openbao.copy_from_host("spire-join-token", "/run/credstore/spire-server-join-token")
    openbao.wait_for_unit("spire-agent.socket")
    openbao.succeed("spire-agent healthcheck -socketPath /run/spire-agent/public/api.sock")

    openbao.wait_for_unit("openbao.service")

    import json

    init_output = json.loads(openbao.succeed("bao operator init"))
    for key in init_output["unseal_keys_b64"][:init_output["unseal_threshold"]]:
      openbao.succeed(f"bao operator unseal {key}")
    openbao.succeed(f"bao login {init_output["root_token"]}")

    print(init_output["root_token"])

    openbao.succeed("bao secrets enable -version=2 kv")
    openbao.succeed("bao kv put -mount=kv foo secret=ubersecret")
    openbao.succeed("echo 'path \"kv/data/foo\" { capabilities = [\"read\"]}' | bao policy write access-foo -")

    openbao.succeed("bao auth enable cert")
    openbao.succeed("bao write auth/cert/config enable_identity_alias_metadata=true")
    openbao.succeed("bao write auth/cert/certs/openbao certificate=@/run/credstore/spire-server-bundle allowed_uri_sans=spiffe://example.com/service/openbao token_policies=access-foo")
    openbao.succeed("bao write auth/cert/certs/agent certificate=@/run/credstore/spire-server-bundle allowed_uri_sans=spiffe://example.com/service/agent token_policies=access-foo")
    openbao.succeed("bao write auth/cert/certs/admin certificate=@/run/credstore/spire-server-bundle allowed_uri_sans=spiffe://example.com/user/admin token_policies=access-foo")

    openbao.succeed("bao login -method=cert")
    openbao.succeed("bao kv get -mount=kv foo")

    agent.succeed("spire-agent api fetch x509 -socketPath /run/spire-agent/public/api.sock -write .")
    agent.succeed("bao login -method=cert -ca-cert=bundle.0.pem -client-cert=svid.0.pem -client-key=svid.0.key")
    agent.succeed("VAULT_CACERT=bundle.0.pem bao kv get -mount=kv foo")

  '';

}
