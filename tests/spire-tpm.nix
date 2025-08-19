{ lib, pkgs, ... }:
let
  trustDomain = "example.com";
in
{
  name = "spire-tpm";
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
            NodeAttestor  "tpm" {
              plugin_cmd = "${lib.getExe' pkgs.spire-tpm-plugin "tpm_attestor_server"}"
              plugin_data {
                hash_path = "/etc/spire/server/hashes"
              }
            }

          }
        '';
      };
    };
    agent = {
      imports = [ ../modules/spire/agent.nix ];
      networking.firewall.allowedTCPPorts = [ 80 ];
      systemd.services.spire-agent.serviceConfig.LoadCredential = "spire-server-bundle";

      # TODO: use the swtpm-setup tooling instead. But that is supposed to run before tpm2_startup IIRC

      virtualisation.tpm = {
        enable = true;
      };

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
            NodeAttestor "tpm" {
              plugin_cmd = "${lib.getExe' pkgs.spire-tpm-plugin "tpm_attestor_agent"}"
              plugin_data {}
            }
            WorkloadAttestor "systemd" {
              plugin_data {}
            }
          }
        '';
      };
    };
  };
  # TODO: use ekcert based provisioning
  testScript = ''
    pubhash = agent.succeed("${lib.getExe' pkgs.spire-tpm-plugin "get_tpm_pubhash"}").strip()
    server.succeed("mkdir -p /etc/spire/server/hashes")
    server.succeed(f"touch /etc/spire/server/hashes/{pubhash}")
    server.wait_for_unit("spire-server.socket")
    bundle = server.succeed("spire-server bundle show -socketPath /run/spire-server/private/api.sock")
    with open("bundle.pem", "w") as f:
        f.write(bundle)
    agent.copy_from_host("bundle.pem", "/run/credstore/spire-server-bundle")
    agent.succeed("spire-agent api fetch x509 -socketPath /run/spire-agent/public/api.sock -write .")
  '';
}
