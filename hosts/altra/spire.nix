{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../modules/spire/controller-manager.nix
    ../../modules/spire/oidc-discovery-provider.nix
  ];

  services.spire.agent = {
    enable = true;
    settings = {
      agent = {
        trust_bundle_url = "https://spire-server.nixos.sh:8443";
        trust_bundle_format = "spiffe";
        server_address = "spire-server.nixos.sh";
        rebootstrap_mode = "auto";
        rebootstrap_delay = "2m";
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
        "tpm:manufacturer:id:4E544300"
        "tpm:model:NPCT75x"
        "tpm:version:id:00070002"
        "tpm:pub_hash:856dd0443668292a66fabd29f778345f7c1a82bbc9b55d99ceb462cdba0897f6"
      ];
    };
    arian.spec = {
      parentID = "spiffe://nixos.sh/server/altra";
      spiffeID = "spiffe://nixos.sh/user/arian";
      selectors = [ "unix:uid:1000" ];
    };
  };

  systemd.services.spire-server = {
    after = [ "acme-spire-server.nixos.sh.service" ];
    wants = [ "acme-spire-server.nixos.sh.service" ];
    serviceConfig.LoadCredential = [
      "fullchain.pem:${config.security.acme.certs."spire-server.nixos.sh".directory}/fullchain.pem"
      "key.pem:${config.security.acme.certs."spire-server.nixos.sh".directory}/key.pem"
    ];
  };

  # nixbot's nginx is off (Cloudflare tunnel), so nothing else serves :80/:443.
  # This also puts websites/nixos.sh back online.
  services.nginx.enable = true;
  security.acme.certs."spire-server.nixos.sh".reloadServices = [ "spire-server.service" ];
  services.nginx.virtualHosts."spire-server.nixos.sh" = {
    enableACME = true;
    forceSSL = true;
    locations."/".return = "404";
  };
  services.nginx.virtualHosts."id.nixos.sh" = {
    enableACME = true;
    forceSSL = true;
    locations."/".proxyPass = "http://127.0.0.1:8090";
  };
  networking.firewall.allowedTCPPorts = [ 8443 ];

  spire.oidc-discovery-provider = {
    enable = true;
    settings = {
      domains = [ "id.nixos.sh" ];
      jwt_issuer = "https://id.nixos.sh";
      insecure_addr = "127.0.0.1:8090";
      set_key_use = true;
      server_api.poll_interval = "10s";
    };
  };
  systemd.services.spire-oidc-discovery-provider.serviceConfig = {
    # the server's dynamic user, so it can open the private API socket
    DynamicUser = true;
    User = "spire-server";
  };

  services.spire.server = {
    enable = true;
    settings = {
      server = {
        trust_domain = "nixos.sh";
        log_level = "debug";
        # Numtide's farm daemons and niks3 validate this trust domain's
        # JWT-SVIDs through OIDC discovery at this issuer.
        jwt_issuer = "https://id.nixos.sh";
        federation = {
          # nginx does ACME for this name and id.nixos.sh and terminates the
          # OIDC issuer on :443; the bundle endpoint serves that certificate
          # on 8443. SPIRE's own ACME would need :443 for TLS-ALPN.
          bundle_endpoint = {
            address = "::";
            port = 8443;
            profile.https_web.serving_cert_file = {
              cert_file_path = "/run/credentials/spire-server.service/fullchain.pem";
              key_file_path = "/run/credentials/spire-server.service/key.pem";
              file_sync_interval = "1h";
            };
          };
          federates_with."numtide.com" = {
            bundle_endpoint_url = "https://spire.numtide.com:8443";
            bundle_endpoint_profile.https_web = { };
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
