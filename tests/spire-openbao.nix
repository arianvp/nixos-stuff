# What is left of the old spire-join-token test after join_token attestation
# itself moved upstream (nixos/tests/spire.nix). The join token here is only a
# means of bootstrapping the agents; what this test actually covers is the
# pieces that are not upstream: spire-controller-manager static entries, and
# OpenBao bootstrapped from SPIRE (modules/spire/openbao.nix), which
# initializes and unseals itself and authenticates workloads by their SPIFFE
# URI SAN, also after the SPIRE CA rotates.
{ pkgs, lib, ... }:
let
  trustDomain = "example.com";

  spireAgent =
    { config, ... }:
    {
      # The upstream module does not export this the way our old local module
      # did, so set it here for the test script's sake.
      environment.variables.SPIFFE_ENDPOINT_SOCKET =
        config.services.spire.agent.settings.agent.socket_path;

      # Written into each machine's state_dir by the test script before it boots
      virtualisation.credentials = {
        "spire.trust_bundle".source = "./trust_bundle";
        "spire.join_token".source = "./join_token";
      };
      systemd.services.spire-agent.serviceConfig.ImportCredential = [
        "spire.trust_bundle"
        "spire.join_token"
      ];

      services.spire.agent = {
        enable = true;
        settings = {
          agent = {
            trust_domain = trustDomain;
            server_address = "server.${trustDomain}";
            trust_bundle_path = "$CREDENTIALS_DIRECTORY/spire.trust_bundle";
            trust_bundle_format = "pem";
            join_token_file = "$CREDENTIALS_DIRECTORY/spire.join_token";
          };
          plugins = {
            KeyManager.memory.plugin_data = { };
            NodeAttestor.join_token.plugin_data = { };
            WorkloadAttestor.systemd.plugin_data = { };
            WorkloadAttestor.unix.plugin_data = { };
          };
        };
      };

      environment.systemPackages = [
        pkgs.openbao
        pkgs.jq
      ];
      environment.variables = {
        VAULT_ADDR = "https://openbao.${trustDomain}:8200";
        VAULT_FORMAT = "json";
      };
    };
in
{
  name = "spire-openbao";
  globalTimeout = 420;

  defaults.networking.domain = trustDomain;

  nodes = {
    openbao = {
      imports = [
        spireAgent
        ../modules/spire/openbao.nix
      ];

      spire.openbao = {
        enable = true;
        spiffeID = "spiffe://${trustDomain}/service/openbao";
        dnsName = "openbao.${trustDomain}";
        # A real key would be encrypted with systemd-creds
        sealKey.file = pkgs.writeText "openbao-seal-key" "0f1e2d3c4b5a69788796a5b4c3d2e1f00112233445566778899aabbccddeeff0";
        policies.access-foo = ''
          path "kv/foo" {
            capabilities = ["read"]
          }
        '';
        certRoles = {
          agent = {
            allowedURISANs = [ "spiffe://${trustDomain}/service/agent" ];
            policies = [ "access-foo" ];
          };
          admin = {
            allowedURISANs = [ "spiffe://${trustDomain}/user/admin" ];
            policies = [ "access-foo" ];
          };
        };
        initialize = [
          {
            operation = "update";
            path = "sys/mounts/kv";
            data.type = "kv";
          }
          {
            operation = "update";
            path = "kv/foo";
            data.secret = "ubersecret";
          }
        ];
      };
    };

    server = {
      environment.systemPackages = [ pkgs.openssl ];
      imports = [
        ../modules/spire/controller-manager.nix
      ];
      services.spire.controllerManager = {
        enable = true;
        staticEntries = {
          openbao.spec = {
            selectors = [ "systemd:id:openbao-svid.service" ];
            parentID = "spiffe://${trustDomain}/server/openbao";
            spiffeID = "spiffe://${trustDomain}/service/openbao";
            dnsNames = [ "openbao.${trustDomain}" ];
          };
          root.spec = {
            selectors = [ "unix:uid:0" ];
            parentID = "spiffe://${trustDomain}/server/agent";
            spiffeID = "spiffe://${trustDomain}/service/agent";
            dnsNames = [ "agent.${trustDomain}" ];
          };
          # Not uid 0, which OpenBao's spiffe-helper runs as on that node
          admin.spec = {
            selectors = [ "systemd:id:backdoor.service" ];
            parentID = "spiffe://${trustDomain}/server/openbao";
            spiffeID = "spiffe://${trustDomain}/user/admin";
          };
        };
      };
      services.spire.server = {
        enable = true;
        openFirewall = true;
        settings = {
          server = {
            trust_domain = trustDomain;
            # SPIRE prepares the next CA after half of this and switches to it
            # after five sixths, all within the test
            ca_ttl = "3m";
            default_x509_svid_ttl = "1m";
          };
          plugins = {
            KeyManager.memory.plugin_data = { };
            DataStore.sql.plugin_data = {
              database_type = "sqlite3";
              connection_string = "$STATE_DIRECTORY/datastore.sqlite3";
            };
            NodeAttestor.join_token.plugin_data = { };
            # OpenBao names identity aliases after the subject CN, which SPIRE
            # only sets from DNS names
            CredentialComposer.x509 = {
              plugin_cmd = lib.getExe pkgs.spire-credentialcomposer-x509;
              plugin_data_file = "${(pkgs.formats.json { }).generate "composer.json" {
                subjects = [
                  {
                    spiffe_id = "(spiffe://.+)";
                    common_name = "$1";
                  }
                ];
              }}";
            };
          };
        };
      };
    };

    agent = spireAgent;
  };

  testScript =
    { nodes, ... }:
    let
      adminSocket = nodes.server.services.spire.server.settings.server.socket_path;
    in
    ''
      import json

      def provision(agent, spiffe_id):
        bundle = server.succeed("spire-server bundle show -socketPath ${adminSocket}")
        with open(agent.state_dir / "trust_bundle", "w") as f:
            f.write(bundle)
        token = server.succeed(f"spire-server token generate -socketPath ${adminSocket} -spiffeID {spiffe_id}").split()[1]
        with open(agent.state_dir / "join_token", "w") as f:
            f.write(token)

      def read_secret(machine, role):
        """Logs in with the machine's SVID and reads the secret"""
        machine.succeed("mkdir -p svid && spire-agent api fetch x509 -socketPath $SPIFFE_ENDPOINT_SOCKET -write svid > /dev/null")
        return json.loads(machine.succeed(
            "export VAULT_CACERT=svid/bundle.0.pem"
            f" && bao login -method=cert -client-cert=svid/svid.0.pem -client-key=svid/svid.0.key name={role} > /dev/null"
            " && bao kv get -mount=kv -field=secret foo"
        ))

      with subtest("SPIRE controller manager comes up against the server"):
          server.wait_for_unit("spire-server.service", timeout=60)
          server.wait_until_succeeds("spire-server healthcheck -socketPath ${adminSocket}", timeout=30)
          server.wait_for_unit("spire-controller-manager.service", timeout=60)
          server.succeed("spire-server bundle show -socketPath ${adminSocket} > old-ca.pem")

      with subtest("Bootstrap SPIRE agents"):
          provision(agent, "spiffe://example.com/server/agent")
          provision(openbao, "spiffe://example.com/server/openbao")
          for m in [agent, openbao]:
              m.wait_for_unit("spire-agent.service", timeout=60)
              m.wait_until_succeeds("spire-agent healthcheck -socketPath $SPIFFE_ENDPOINT_SOCKET", timeout=30)

      with subtest("OpenBao initializes and unseals itself"):
          openbao.wait_for_unit("openbao.service", timeout=120)
          openbao.wait_for_unit("openbao-config.service", timeout=60)
          status = json.loads(openbao.succeed("VAULT_CACERT=/run/openbao-svid/bundle.pem bao status"))
          assert status["initialized"] and not status["sealed"], status

      with subtest("Workloads authenticate with their X509-SVID"):
          assert read_secret(agent, "agent") == "ubersecret"
          assert read_secret(openbao, "admin") == "ubersecret"

      with subtest("Roles only admit their SPIFFE IDs"):
          agent.fail(
              "VAULT_CACERT=svid/bundle.0.pem bao login -method=cert"
              " -client-cert=svid/svid.0.pem -client-key=svid/svid.0.key name=admin"
          )

      with subtest("OpenBao unseals itself after a restart"):
          openbao.systemctl("restart openbao.service")
          openbao.wait_until_succeeds(
              "VAULT_CACERT=/run/openbao-svid/bundle.pem bao status | jq -e '.sealed == false'", timeout=60
          )
          assert read_secret(agent, "agent") == "ubersecret"

      with subtest("Cert auth trusts the new CA after SPIRE rotates it"):
          # Nothing may rely on the old CA once it has expired
          server.wait_until_fails("openssl x509 -in old-ca.pem -noout -checkend 0", timeout=300)
          assert read_secret(agent, "agent") == "ubersecret"
          assert read_secret(openbao, "admin") == "ubersecret"
    '';
}
