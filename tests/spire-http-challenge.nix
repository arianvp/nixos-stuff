let
  trustDomain = "example.com";
  agentConfig = {
    imports = [ ../modules/spire/agent.nix ];
    networking.firewall.allowedTCPPorts = [ 80 ];
    systemd.services.spire-agent.serviceConfig.LoadCredential = "spire-server-bundle";
    spire.agent = {
      enable = true;
      trustDomain = trustDomain;
      trustBundle = "\${CREDENTIALS_DIRECTORY}/spire-server-bundle";
      trustBundleFormat = "pem";
      serverAddress = "server";
      config = ''
        plugins {
          KeyManager "memory" { plugin_data { } }
          NodeAttestor "http_challenge" {
            plugin_data { port = 80 }
          }
          WorkloadAttestor "systemd" { plugin_data { } }
        }
      '';
    };
  };
in
{
  name = "spire-http-challenge";
  nodes = {
    server = {
      imports = [
        ../modules/spire/server.nix
        ../modules/spire/controller-manager.nix
      ];
      spire.controllerManager = {
        enable = true;
        staticEntries = {
          node.spec = {
            selectors = [ "http_challenge:hostname:agent2" ];
            parentID = "spiffe://${trustDomain}/spire/server";
            spiffeID = "spiffe://${trustDomain}/node/agent";
          };
          agent-alias.spec = {
            selectors = [ "systemd:id:backdoor.service" ];
            parentID = "spiffe://${trustDomain}/node/agent";
            spiffeID = "spiffe://${trustDomain}/service/agent";
          };
          agent1.spec = {
            selectors = [ "systemd:id:backdoor.service" ];
            parentID = "spiffe://${trustDomain}/spire/agent/http_challenge/agent1";
            spiffeID = "spiffe://${trustDomain}/service/agent";
          };
        };
      };
      spire.server = {
        enable = true;
        inherit trustDomain;
        config = ''
          plugins {
            KeyManager "memory" { plugin_data {} }
            DataStore "sql" {
              plugin_data {
                database_type = "sqlite3"
                connection_string = "$STATE_DIRECTORY/datastore.sqlite3"
              }
            }
            NodeAttestor  "http_challenge" {
              plugin_data { required_port = "80" }
            }

          }
        '';
      };
    };
    agent1 = agentConfig;
    agent2 = agentConfig;
  };

  testScript = ''
    server.wait_for_unit("spire-server.socket")
    bundle = server.succeed("spire-server bundle show -socketPath $SPIRE_SERVER_ADMIN_SOCKET")
    with open("bundle.pem", "w") as f:
        f.write(bundle)


    with subtest("no alias"):
      agent1.copy_from_host("bundle.pem", "/run/credstore/spire-server-bundle")
      # Will succeed immediately as X509-SVID is fetched before $SPIFFE_ENDPOINT_SOCKET accepts connections
      agent1.succeed("spire-agent api fetch x509 -socketPath $SPIFFE_ENDPOINT_SOCKET -write .")

    # regression test for: https://github.com/spiffe/spire/issues/6257
    with subtest("alias"):
      agent2.copy_from_host("bundle.pem", "/run/credstore/spire-server-bundle")
      # First call will fail as the X509-SVID is fetched asynchronously instead of synchronously for aliases :(
      agent2.fail("spire-agent api fetch x509 -socketPath $SPIFFE_ENDPOINT_SOCKET -write .")
      # Now wait for  the SVID to be created asynchronously :(
      agent2.wait_for_console_text("Creating X509-SVID")
      agent2.succeed("spire-agent api fetch x509 -socketPath $SPIFFE_ENDPOINT_SOCKET -write .")

  '';
}
