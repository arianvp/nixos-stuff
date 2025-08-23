{ lib, pkgs, ... }:
{
  imports = [
    ../../modules/spire/server.nix
    ../../modules/spire/controller-manager.nix
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

  spire.controllerManager.staticEntries = {
    altra = {
      parentID = "spiffe://nixos.sh/spire/server";
      spiffeID = "spiffe://nixos.sh/server/altra";
      selectors = [
        "tpm:tpm_manufacturer:id:4E544300"
        "tpm:tpm_model:NPCT75x"
        "tpm:tpm_version:id:00070002"
      ];
    };
    prometheus = {
      parentID = "spiffe://nixos.sh/server/altra";
      spiffeID = "spiffe://nixos.sh/server/prometheus";
      selectors = [ "systemd:id:prometheus.service" ];
    };

  };

  spire.server = {
    enable = true;
    trustDomain = "nixos.sh";
    logLevel = "debug";
    config = # hcl
      ''
        plugins {
          KeyManager "disk" {
            plugin_data {
              keys_path = "$STATE_DIRECTORY/keys.json"
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
              # could not verify cert: x509: unhandled critical extension"
              ca_path = "${../../modules/spire/certs}"
              # hash_path = "${
                pkgs.runCommand "hash-path" { } ''
                  mkdir -p $out
                  touch $out/856dd0443668292a66fabd29f778345f7c1a82bbc9b55d99ceb462cdba0897f6
                ''
              }"
            }
          }
        }
      '';
  };
}
