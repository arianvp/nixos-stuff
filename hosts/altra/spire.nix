{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../modules/spire/controller-manager.nix
  ];

  services.spire.agent = {
    enable = true;
    settings = {
      agent = {
        trust_bundle_url = "https://spire-server.nixos.sh";
        trust_bundle_format = "spiffe";
        server_address = "spire-server.nixos.sh";
        trust_domain = "nixos.sh";
        log_level = "debug";
      };
      plugins.KeyManager.disk.plugin_data.directory = "$STATE_DIRECTORY";
      plugins.WorkloadAttestor.unix.plugin_data = { };
      plugins.WorkloadAttestor.systemd.plugin_data = { };
      plugins.NodeAttestor.tpm = {
        plugin_cmd = lib.getExe' pkgs.spire-tpm-plugin "tpm_attestor_agent";
        plugin_data = { };
      };
    };
  };

  environment.variables.SPIFFE_ENDPOINT_SOCKET =
    config.services.spire.agent.settings.agent.socket_path;
  systemd.globalEnvironment.SPIFFE_ENDPOINT_SOCKET =
    config.services.spire.agent.settings.agent.socket_path;

  environment.systemPackages = [ pkgs.spire-tpm-plugin ];

  services.spire.controllerManager.enable = true;
  services.spire.controllerManager.staticEntries = {
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

  systemd.services.spire-server.serviceConfig = {
    AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
    CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
  };

  services.spire.server = {
    enable = true;
    settings = {
      server = {
        trust_domain = "nixos.sh";
        log_level = "debug";
        federation = {
          bundle_endpoint = {
            address = "0.0.0.0";
            port = 443;
            acme = {
              domain_name = "spire-server.nixos.sh";
              email = "arian.vanputten@gmail.com";
              tos_accepted = true;
            };
          };
        };
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
            ca_path = "${../../modules/spire/certs}"; # TODO: types.path
          };
        };

      };
    };
  };
}
