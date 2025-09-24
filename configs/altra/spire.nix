{ lib, pkgs, ... }:
{
  imports = [
    ../../modules/spire/server.nix
    ../../modules/spire/controller-manager.nix
    ../../modules/spire/agent-tpm.nix
  ];


  spire.agent = {
    enable = true;
    settings = {
      agent = {
        insecure_bootstrap = true;  # TODO: Get a proper trust bundle instead of TOFU
        # trust_bundle_path = "$STATE_DIRECTORY/bundle.pem";
        # trust_bundle_format = "pem";
        server_address = "localhost";
        trust_domain = "nixos.sh";
        log_level = "debug";
      };
      plugins.KeyManager.disk.plugin_data.directory = "$STATE_DIRECTORY/keys";
      plugins.WorkloadAttestor.unix.plugin_data = {};
      plugins.WorkloadAttestor.systemd.plugin_data = {};
    };
  };

  environment.systemPackages = [ pkgs.spire-tpm-plugin ];

  spire.controllerManager.enable = true;
  spire.controllerManager.staticEntries = {
    altra.spec = {
      parentID = "spiffe://nixos.sh/spire/server";
      spiffeID = "spiffe://nixos.sh/server/altra";
      selectors = [
        "tpm:tpm_manufacturer:id:4E544300"
        "tpm:tpm_model:NPCT75x"
        "tpm:tpm_version:id:00070002"
        "tpm:pub_hash:856dd0443668292a66fabd29f778345f7c1a82bbc9b55d99ceb462cdba0897f6"
      ];
    };
    arian.spec = {
      parentID = "spiffe://nixos.sh/server/altra";
      spiffeID = "spiffe://nixos.sh/user/arian";
      selectors = [ "unix:uid:1000" ];
    };
  };

  spire.server = {
    enable = true;
    settings = {
      server = {
        trust_domain = "nixos.sh";
        log_level = "debug";
      };
      plugins = {
        KeyManager.disk.plugin_data.keys_path = "$STATE_DIRECTORY/keys.json";
        DataStore.sql.plugin_data = {
          database_type = "sqlite3";
          connection_string = "$STATE_DIRECTORY/datastore.sqlite3";
        };
        NodeAttestor.http_challenge.plugin_data = {
          required_port = 80;
          allowed_dns_patterns = [ ".*\\.nixos.sh" ];
        };
        NodeAttestor.join_token.plugin_data = { };
        NodeAttestor.tpm = {
          plugin_cmd = lib.getExe' pkgs.spire-tpm-plugin "tpm_attestor_server";
          plugin_data = {
            ca_path = ../../modules/spire/certs;
          };
        };

      };
    };
  };
}
