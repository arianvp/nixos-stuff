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
            selectors = [ "tpm:tpm_model:ST33HTPHAHD4" ];
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
        settings = {
          server = {
            trust_domain = trustDomain;
            log_level = "debug";
          };
          plugins = {
            KeyManager.memory.plugin_data = { };
            DataStore.sql = {
              plugin_data = {
                database_type = "sqlite3";
                connection_string = "$STATE_DIRECTORY/datastore.sqlite3";
              };
            };
            NodeAttestor.tpm = {
              plugin_cmd = lib.getExe' pkgs.spire-tpm-plugin "tpm_attestor_server";
              plugin_data.ca_path = "/etc/spire/server/certs";
            };
          };
        };
      };

      environment.etc."spire/server/certs/tpm-ca.crt".source = ./tpm-ca.crt;
    };
    agent = {
      imports = [
        ../modules/spire/agent.nix
        ../modules/spire/agent-tpm.nix
        ../modules/tpm2-ekcert-provisioning.nix
      ];
      networking.firewall.allowedTCPPorts = [ 80 ];
      systemd.services.spire-agent.serviceConfig.LoadCredential = "spire-server-bundle";

      environment.systemPackages = [ pkgs.spire-tpm-plugin ];

      virtualisation = {
        useEFIBoot = true;
        efi.OVMF = pkgs.OVMFFull.fd;

        # Provision an EK and EKCert signed by this CA
        tpm.provisioningRootCA = {
          enable = true;
          key = ./tpm-ca.key;
          certificate = ./tpm-ca.crt;
        };
      };

      spire.agent = {
        enable = true;
        settings = {
          agent = {
            trust_domain = trustDomain;
            log_level = "debug";
            server_address = "server";
            trust_bundle_path = "$CREDENTIALS_DIRECTORY/spire-server-bundle";
            trust_bundle_format = "pem";
          };
          plugins = {
            KeyManager.memory.plugin_data = { };
            WorkloadAttestor.systemd.plugin_data = { };
          };
        };
      };
    };
  };
  testScript = ''
    import pprint
    import json

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
    agents = json.loads(
       server.succeed("spire-server agent list -socketPath $SPIRE_SERVER_ADMIN_SOCKET -output json")
    )
    pprint.pp(agents)

  '';
}
