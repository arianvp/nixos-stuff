{ lib, pkgs, ... }:
{
  imports = [
    ../../modules/spire/server.nix
    ../../modules/spire/agent-tpm.nix
  ];

  spire.agent = {
    enable = true;
    trustBundleUrl = "https://spire.nixos.sh";
    trustBundleFormat = "spiffe";
    serverAddress = "spire.nixos.sh";
    trustDomain = "nixos.sh";
  };

  spire.server = {
    enable = true;
    trustDomain = "nixos.sh";
    config = # hcl
      ''
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
          NodeAttestor "http_challenge" {
            plugin_data {
              required_port = 80
              allowed_dns_patterns = [".*\.nixos.sh"]
            }
          }
          NodeAttestor "join_token" {
            plugin_data {
            }
          }
          NodeAttestor  "tpm" {
            plugin_cmd = "${lib.getExe' pkgs.spire-tpm-plugin "tpm_attestor_server"}"
            plugin_data {
              cert_path = ${../modules/spire/certs}
            }
          }
        }
      '';
  };
}
