{ lib, pkgs, ... }:
{
  imports = [
    ../../modules/spire/server.nix
    ../../modules/spire/agent-tpm.nix
  ];

  # hack to not have to depend on one-self
  systemd.services.spire-agent.preStart = ''
    ${pkgs.spire-server}/bin/spire-server bundle show -socketPath $SPIRE_SERVER_ADMIN_SOCKET > $STATE_DIRECTORY/bundle.pem
  '';

  spire.agent = {
    enable = true;
    trustBundle = "\${STATE_DIRECTORY}/bundle.pem";
    trustBundleFormat = "pem";
    serverAddress = "localhost";
    trustDomain = "nixos.sh";
    logLevel = "debug";
  };

  environment.systemPackages = [ pkgs.spire-tpm-plugin ];

  spire.server = {
    enable = true;
    trustDomain = "nixos.sh";
    logLevel = "debug";
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
              allowed_dns_patterns = [".*\\.nixos.sh"]
            }
          }
          NodeAttestor "join_token" {
            plugin_data {
            }
          }
          NodeAttestor  "tpm" {
            plugin_cmd = "${lib.getExe' pkgs.spire-tpm-plugin "tpm_attestor_server"}"
            plugin_data {
              # TODO: there seems to be a bug in the spire-tpm-plugin and can't verify my certs :(
              # ca_path = "${../../modules/spire/certs}"
              hash_path =
            }
          }
        }
      '';
  };
}
