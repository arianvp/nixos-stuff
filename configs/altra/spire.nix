let
  static = "2a05:2d01:2025:f000:dead:beef:babe:cafe";
in
{
  imports = [ ../../modules/spire/server.nix ];

  systemd.network.networks.eth.address = [ static ];

  spire.server = {
    enable = true;
    trustDomain = "nixos.sh";
    config = /* hcl */ ''
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
