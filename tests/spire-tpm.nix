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
        staticEntries = {
          server.spec = {
            parentID = "spiffe://${trustDomain}/spire/server";
            spiffeID = "spiffe://${trustDomain}/server/agent";
            selectors = [ "tpm:pub_hash:$PUBHASH" ];
          };
          services.spec = {
            selectors = [ "systemd:id:backdoor.service" ];
            parentID = "spiffe://${trustDomain}/server/agent";
            spiffeID = "spiffe://${trustDomain}/service/agent";
          };
        };
      };
      spire.server = {
        enable = true;
        inherit trustDomain;
        logLevel = "debug";
        settings = {
          plugins = {
            KeyManager.memory = {
              plugin_data = { };
            };
            DataStore.sql = {
              plugin_data = {
                database_type = "sqlite3";
                connection_string = "$STATE_DIRECTORY/datastore.sqlite3";
              };
            };
            NodeAttestor.tpm = {
              plugin_cmd = lib.getExe' pkgs.spire-tpm-plugin "tpm_attestor_server";
              plugin_data = {
                hash_path = "/etc/spire/server/hashes";
              };
            };
          };
        };
      };
    };
    agent = {
      imports = [ ../modules/spire/agent.nix ];
      networking.firewall.allowedTCPPorts = [ 80 ];
      systemd.services.spire-agent.serviceConfig.LoadCredential = "spire-server-bundle";

      environment.systemPackages = [ pkgs.spire-tpm-plugin ];

      # TODO: use the swtpm-setup tooling instead. But that is supposed to run before tpm2_startup IIRC

      virtualisation.tpm = {
        enable = true;
      };

      spire.agent = {
        enable = true;
        trustDomain = trustDomain;
        logLevel = "debug";
        serverAddress = "server";
        trustBundle = "\${CREDENTIALS_DIRECTORY}/spire-server-bundle";
        trustBundleFormat = "pem";
        settings = {
          plugins = {
            KeyManager.memory.plugin_data = { };
            NodeAttestor.tpm = {
              plugin_cmd = lib.getExe' pkgs.spire-tpm-plugin "tpm_attestor_agent";
              plugin_data = { };
            };
            WorkloadAttestor.systemd.plugin_data = { };
          };
        };
      };
    };
  };
  # TODO: use ekcert based provisioning
  testScript = ''
    pubhash = agent.succeed("get_tpm_pubhash").strip()
    server.succeed("mkdir -p /etc/spire/server/hashes")
    server.succeed(f"touch /etc/spire/server/hashes/{pubhash}")
    server.succeed(f"systemctl set-environment PUBHASH={pubhash}")
    # NOTE: to pick up the new env var
    server.succeed("systemctl restart spire-controller-manager")
    server.wait_for_unit("spire-server.socket")
    bundle = server.succeed("spire-server bundle show -socketPath $SPIRE_SERVER_ADMIN_SOCKET")
    with open("bundle.pem", "w") as f:
        f.write(bundle)
    agent.copy_from_host("bundle.pem", "/run/credstore/spire-server-bundle")

    # First call will fail as the X509-SVID is fetched asynchronously instead of synchronously for aliases :(
    agent.fail("spire-agent api fetch x509 -socketPath $SPIFFE_ENDPOINT_SOCKET -write .")
    # Now wait for the SVID to be created asynchronously :(
    # FIXME: workaround for https://github.com/spiffe/spire/issues/6257
    agent.wait_for_console_text("Creating X509-SVID")
    agent.succeed("spire-agent api fetch x509 -socketPath $SPIFFE_ENDPOINT_SOCKET -write .")
  '';
}
