{ pkgs, lib, ... }:
let
  trustDomain = "example.com";
in
{
  name = "spire-join-token";

  interactive.sshBackdoor.enable = true;

  defaults = {
    networking.domain = trustDomain;
    spire.agent.trustDomain = trustDomain;
    spire.agent.serverAddress = "server.${trustDomain}";
    imports = [ ../modules/spire/agent.nix ];

    systemd.services.spire-agent.serviceConfig = {
      LoadCredential = [ "spire-server-bundle" ];
      EnvironmentFile = "/run/credstore/spire-join-token";
    };

    spire.agent = {
      enable = true;
      trustBundle = "\${CREDENTIALS_DIRECTORY}/spire-server-bundle";
      trustBundleFormat = "pem";
      joinToken = "\${SPIRE_JOIN_TOKEN}";
      config = ''
        plugins {
          KeyManager "memory" { plugin_data { } }
          NodeAttestor "join_token" { plugin_data { } }
          WorkloadAttestor "systemd" { plugin_data { } }
          WorkloadAttestor "unix" {
            plugin_data {
              discover_workload_path = true
            }
          }
        }
      '';
    };
  };

  nodes = {
    openbao =
      { config, ... }:
      {

        networking.firewall.allowedTCPPorts = [ 8200 ];

        systemd.services.openbao.serviceConfig.ExecStartPre =
          "${lib.getExe' pkgs.spire "spire-agent"} api fetch x509 -socketPath $SPIFFE_ENDPOINT_SOCKET -write $RUNTIME_DIRECTORY";

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
      spire.controllerManager = {
        enable = true;
        staticEntries = {
          openbao.spec = {
            selectors = [ "systemd:id:openbao.service" ];
            parentID = "spiffe://${trustDomain}/server/openbao";
            spiffeID = "spiffe://${trustDomain}/service/openbao";
            dnsNames = [ "openbao.${trustDomain}" ];
          };
          root.spec = {
            selectors = [ "unix:uid:0" ];
            parentID = "spiffe://${trustDomain}/server/agent";
            spiffeID = "spiffe://${trustDomain}/service/agent";
            dnsNames = [ "agent.${trustDomain}" ];
          };
          admin.spec = {
            selectors = [ "unix:uid:0" ];
            parentID = "spiffe://${trustDomain}/server/openbao";
            spiffeID = "spiffe://${trustDomain}/user/admin";
            dnsNames = [ "admin.openboa.${trustDomain}" ]; # https://github.com/hashicorp/vault/issues/6820
          };
        };
      };
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
    import json

    def provision(agent, spiffe_id):
      token = server.succeed(f"spire-server token generate -socketPath $SPIRE_SERVER_ADMIN_SOCKET -spiffeID {spiffe_id}").split()[1]
      with open("spire-join-token", "w") as f:
          f.write(f"SPIRE_JOIN_TOKEN={token}")
      agent.copy_from_host("spire-join-token", "/run/credstore/spire-join-token")
      agent.copy_from_host("bundle.pem", "/run/credstore/spire-server-bundle")


    with subtest("SPIRE server startup and health checks"):
        server.wait_for_unit("spire-server.socket")
        server.wait_for_unit("spire-server-local.socket")
        server.succeed("spire-server healthcheck -socketPath $SPIRE_SERVER_ADMIN_SOCKET")
        server.succeed("curl -kv https://server:8081")
        server.wait_for_unit("spire-controller-manager.service")

    with subtest("Generate and distribute SPIRE credentials"):
        # Get the trust bundle
        bundle = server.succeed("spire-server bundle show -socketPath $SPIRE_SERVER_ADMIN_SOCKET")
        with open("bundle.pem", "w") as f:
            f.write(bundle)

    with subtest("Setup SPIRE agent on agent node"):
        provision(agent, "spiffe://example.com/server/agent")
        agent.wait_for_unit("spire-agent.socket")
        agent.succeed("spire-agent healthcheck -socketPath $SPIFFE_ENDPOINT_SOCKET")

    with subtest("Setup SPIRE agent on openbao node"):
        provision(openbao, "spiffe://example.com/server/openbao")
        openbao.wait_for_unit("spire-agent.socket")
        openbao.succeed("spire-agent healthcheck -socketPath $SPIFFE_ENDPOINT_SOCKET")

    with subtest("Initialize and unseal OpenBao"):
        openbao.wait_for_unit("openbao.service")

        # Initialize OpenBao
        init_output = json.loads(openbao.succeed("bao operator init"))

        # Unseal with required threshold of keys
        for key in init_output["unseal_keys_b64"][:init_output["unseal_threshold"]]:
            openbao.succeed(f"bao operator unseal {key}")

        # Login with root token
        openbao.succeed(f"bao login {init_output['root_token']}")
        print(f"OpenBao root token: {init_output['root_token']}")

    with subtest("Configure OpenBao secrets and policies"):
        # Enable KV secrets engine and create test secret
        openbao.succeed("bao secrets enable -version=2 kv")
        openbao.succeed("bao kv put -mount=kv foo secret=ubersecret")

        # Create policy for accessing the secret
        openbao.succeed("echo 'path \"kv/data/foo\" { capabilities = [\"read\"]}' | bao policy write access-foo -")

    with subtest("Configure certificate authentication"):
        # Enable and configure cert auth method
        openbao.succeed("bao auth enable cert")

        # Configure certificate roles for different SPIFFE IDs
        openbao.succeed("bao write auth/cert/certs/openbao certificate=@/run/credstore/spire-server-bundle allowed_uri_sans=spiffe://example.com/service/openbao token_policies=access-foo")
        openbao.succeed("bao write auth/cert/certs/agent certificate=@/run/credstore/spire-server-bundle allowed_uri_sans=spiffe://example.com/service/agent token_policies=access-foo")
        openbao.succeed("bao write auth/cert/certs/admin certificate=@/run/credstore/spire-server-bundle allowed_uri_sans=spiffe://example.com/user/admin token_policies=access-foo")

    with subtest("Test certificate authentication from openbao node"):
        # Test direct cert auth on openbao node
        openbao.succeed("bao login -method=cert")
        openbao.succeed("bao kv get -mount=kv foo")

    with subtest("Test certificate authentication from agent node"):
        # Fetch SVID certificates on agent
        agent.succeed("spire-agent api fetch x509 -socketPath $SPIFFE_ENDPOINT_SOCKET -write .")

        # Test cert auth using fetched certificates
        agent.succeed("bao login -method=cert -ca-cert=bundle.0.pem -client-cert=svid.0.pem -client-key=svid.0.key")
        agent.succeed("VAULT_CACERT=bundle.0.pem bao kv get -mount=kv foo")

  '';

}
