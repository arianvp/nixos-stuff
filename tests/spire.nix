{ pkgs, lib, ... }:
{
  name = "spire";

  nodes = {
    server = {
      imports = [ ../modules/spire/server.nix ];


      spire.server = {
        enable = true;
        trustDomain = "example.com";
        entries.root = {
          selectors = [ { type = "unix"; value = "uid:0"; } ];
          parent_id = "spiffe://example.com/server/agent";
          spiffe_id = "spiffe://example.com/user/root";
        };
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
      imports = [ ../modules/spire/agent.nix ];

      systemd.services.spire-agent.serviceConfig = {
        EnvironmentFile = "/run/credstore/spire-server-join-token";
        LoadCredential = "spire-server-bundle";
      };

      spire.agent = {
        enable = true;
        trustDomain = "example.com";
        serverAddress = "server";
        config = ''
          agent {
            join_token = "$SPIRE_AGENT_JOIN_TOKEN"
            trust_bundle_path = "$CREDENTIALS_DIRECTORY/spire-server-bundle"
            trust_bundle_format = "pem"
          }
          plugins {
            KeyManager "memory" {
              plugin_data {
              }
            }
            NodeAttestor "join_token" {
              plugin_data {
              }
            }

            WorkloadAttestor "systemd" {
              plugin_data {
              }
            }
            WorkloadAttestor "unix" {
              plugin_data {
                discover_workload_path = true
              }
            }
          }
        '';
      };
    };
  };

  testScript = ''
    server.wait_for_unit("spire-server.socket")
    server.wait_for_unit("spire-server-local.socket")

    server.succeed("spire-server healthcheck")
    server.succeed("curl -kv https://server:8081")

    bundle = server.succeed("spire-server bundle show")
    with open("bundle.pem", "w") as f:
        f.write(bundle)

    token = server.succeed("spire-server token generate -spiffeID spiffe://example.com/server/agent").split()[1]
    with open("spire-join-token", "w") as f:
        f.write(f"SPIRE_AGENT_JOIN_TOKEN={token}")

    agent.copy_from_host("bundle.pem", "/run/credstore/spire-server-bundle")
    agent.copy_from_host("spire-join-token", "/run/credstore/spire-server-join-token")
    agent.wait_for_unit("spire-agent.socket")
    agent.succeed("spire-agent healthcheck")
    print(agent.succeed("spire-agent api fetch"))
  '';

}
