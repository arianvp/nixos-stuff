let
  static = "2a05:2d01:2025:f000:dead:beef:babe:cafe";
in
{
  imports = [
    ../../modules/spire/server.nix
    ../../modules/spire/agent.nix
  ];

  systemd.network.networks.eth.address = [ static ];

  spire.agent = {
    enable = true;
    trustBundleUrl = "https://spire.nixos.sh";
    trustBundleFormat = "spiffe";
    serverAddress = "spire.nixos.sh";
    trustDomain = "nixos.sh";
    joinToken = "a6211696-1d1b-4be7-9521-3a8b99961007";
  };

  spire.server.entries = [
    {
      parent_id = "spiffe://nixos.sh/server/altra";
      spiffe_id = "spiffe://nixos.sh/service/prometheus";
      selectors = [
        {
          type = "systemd";
          value = "prometheus";
        }
      ];
    }
    {
      parent_id = "spiffe://nixos.sh/server/altra";
      spiffe_id = "spiffe://nixos.sh/service/alertmanager";
      selectors = [
        {
          type = "systemd";
          value = "alertmanager";
        }
      ];
    }

  ];

  spire.server = {
    enable = true;
    trustDomain = "nixos.sh";
    config = # hcl
      ''
        server {
          federation {
            bundle_endpoint {
              address = "${static}"
              port = 443
              profile "https_web" {
                acme {
                  domain_name = "spire.nixos.sh"
                  tos_accepted = true
                }
              }
            }
          }
          jwt_issuer = "https://spire.nixos.sh"
        }

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
}
