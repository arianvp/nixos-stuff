let
  trustDomain = "example.com";
  agentConfig =
    { config, ... }:
    {
      networking.firewall.allowedTCPPorts = [ 80 ];
      systemd.services.spire-agent.serviceConfig.AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];

      # The upstream module does not export this the way our old local module
      # did, so set it here for the test script's sake.
      environment.variables.SPIFFE_ENDPOINT_SOCKET =
        config.services.spire.agent.settings.agent.socket_path;

      services.spire.agent = {
        enable = true;
        settings = {
          agent = {
            log_level = "debug";
            trust_domain = trustDomain;
            trust_bundle_path = ./ca.crt;
            server_address = "server";
          };
          plugins = {
            KeyManager.memory.plugin_data = { };
            NodeAttestor.http_challenge.plugin_data.port = 80;
            WorkloadAttestor.systemd.plugin_data = { };
          };
        };
      };
    };
in
{ nodes, ... }:
let
  adminSocket = nodes.server.services.spire.server.settings.server.socket_path;
in
{
  name = "spire-http-challenge";
  defaults.networking.useNetworkd = true;
  nodes = {
    server = {
      services.spire.server = {
        enable = true;
        openFirewall = true;
        settings = {
          server = {
            audit_log_enabled = true;
            log_level = "debug";
            trust_domain = trustDomain;
          };
          plugins = {
            KeyManager.memory.plugin_data = { };
            UpstreamAuthority.disk.plugin_data = {
              cert_file_path = ./ca.crt;
              key_file_path = ./ca.key;
            };
            DataStore.sql.plugin_data = {
              database_type = "sqlite3";
              connection_string = "$STATE_DIRECTORY/datastore.sqlite3";
            };
            NodeAttestor.http_challenge.plugin_data.required_port = 80;
          };
        };
      };
    };
    agent-without-alias = agentConfig;
    agent-with-alias = agentConfig;
  };

  testScript = ''
    with subtest("IGNORE ME: boot server"):
      server.wait_for_unit("spire-server.service")
      server.wait_until_succeeds("spire-server healthcheck -socketPath ${adminSocket}", timeout=30)

    with subtest("create entries"):
      server.succeed("spire-server entry create -parentID spiffe://${trustDomain}/spire/agent/http_challenge/${nodes.agent-without-alias.networking.hostName} -spiffeID spiffe://${trustDomain}/workload/backdoor -selector systemd:id:backdoor.service -socketPath ${adminSocket}")
      server.succeed("spire-server entry create  -parentID spiffe://${trustDomain}/node/agent -spiffeID spiffe://${trustDomain}/workload/backdoor -selector systemd:id:backdoor.service -socketPath ${adminSocket}")
      server.succeed("spire-server entry create -node -spiffeID spiffe://${trustDomain}/node/agent -selector http_challenge:hostname:${nodes.agent-with-alias.networking.hostName} -socketPath ${adminSocket}")

    with subtest("IGNORE ME: boot agent-without-alias"):
      agent_without_alias.wait_for_unit("multi-user.target")

    with subtest("agent-without-alias"):
      agent_without_alias.succeed("spire-agent api fetch x509 -socketPath $SPIFFE_ENDPOINT_SOCKET -write .")


    with subtest("IGNORE ME: boot agent-with-alias"):
      agent_with_alias.wait_for_unit("multi-user.target")

    with subtest("agent-with-alias"):
      agent_with_alias.fail("spire-agent api fetch x509 -socketPath $SPIFFE_ENDPOINT_SOCKET -write .")
      agent_with_alias.wait_for_console_text("Creating X509-SVID")
      agent_with_alias.succeed("spire-agent api fetch x509 -socketPath $SPIFFE_ENDPOINT_SOCKET -write .")
  '';
}
