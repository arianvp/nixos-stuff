{ pkgs, ... }:
let
  trustDomain = "example.com";
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
        manifests = [
          {
            apiVersion = "spire.spiffe.io/v1alpha1";
            kind = "ClusterStaticEntry";
            metadata.name = "agent";
            spec = {
              selectors = [ "systemd:id:backdoor.service" ];
              parentID = "spiffe://${trustDomain}/spire/agent/http_challenge/agent";
              spiffeID = "spiffe://${trustDomain}/service/agent";
            };
          }
        ];
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
    agent = {
      imports = [ ../modules/spire/agent.nix ];
      networking.firewall.allowedTCPPorts = [ 80 ];
      systemd.services.spire-agent.serviceConfig.LoadCredential = "spire-server-bundle";
      spire.agent = {
        enable = true;
        trustDomain = trustDomain;
        serverAddress = "server";
        config = ''
          agent {
            trust_bundle_path = "$CREDENTIALS_DIRECTORY/spire-server-bundle"
            trust_bundle_format = "pem"
          }
          plugins {
            KeyManager "memory" { plugin_data { } }
            NodeAttestor "http_challenge" {
              plugin_data { port = 80 }
            }
            WorkloadAttestor "systemd" {
              plugin_data {}
            }
          }
        '';
      };
    };
  };
  testScript = ''
    server.wait_for_unit("spire-server.socket")
    bundle = server.succeed("spire-server bundle show -socketPath /run/spire-server/private/api.sock")
    with open("bundle.pem", "w") as f:
        f.write(bundle)
    agent.copy_from_host("bundle.pem", "/run/credstore/spire-server-bundle")
    agent.succeed("spire-agent api fetch x509 -socketPath /run/spire-agent/public/api.sock -write .")
  '';
}
