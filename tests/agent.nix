{
  imports = [ ../modules/spire/agent.nix ];

  systemd.services.spire-agent.serviceConfig = {
    EnvironmentFile = "/run/credstore/spire-server-join-token";
    LoadCredential = "spire-server-bundle";
  };

  spire.agent = {
    enable = true;
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
}
