# Shared setup for the Kubernetes tests: a SPIRE trust domain whose agents
# attest with http_challenge, so nodes need no provisioning from the test script.
{ lib }:
{
  trustDomain = "example.com";
  domain = "example.com";

  # Every node: a SPIRE agent and the SPIRE wiring of the Kubernetes modules
  node =
    { config, ... }:
    {
      imports = [ ./. ];

      networking.domain = "example.com";
      networking.useNetworkd = true;
      # systemd-resolved mixes up the names of addresses that are on several
      # lines of /etc/hosts, as with names that resolve to several nodes
      system.nssDatabases.hosts = lib.mkBefore [ "files" ];

      networking.firewall.allowedTCPPorts = [ 80 ];
      systemd.services.spire-agent.serviceConfig.AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      services.spire.agent = {
        enable = true;
        settings = {
          agent = {
            trust_domain = "example.com";
            server_address = "spire.example.com";
            # SPIRE's own CA rotates; nothing in the cluster may depend on a
            # bundle known in advance
            insecure_bootstrap = true;
          };
          plugins = {
            KeyManager.memory.plugin_data = { };
            NodeAttestor.http_challenge.plugin_data.port = 80;
            WorkloadAttestor.systemd.plugin_data = { };
            WorkloadAttestor.unix.plugin_data = { };
          };
        };
      };

      kubernetes.spire = {
        enable = true;
        parentID = "spiffe://example.com/spire/agent/http_challenge/${config.networking.hostName}";
        # The test driver's shell
        admins.root = [ "systemd:id:backdoor.service" ];
      };
    };

  # The SPIRE server, which registers what every node asks for. Every node
  # needs spireHosts pointing at it.
  server =
    { nodes, ... }:
    {
      services.spire.server = {
        enable = true;
        openFirewall = true;
        settings = {
          server.trust_domain = "example.com";
          plugins = {
            KeyManager.memory.plugin_data = { };
            DataStore.sql.plugin_data = {
              database_type = "sqlite3";
              connection_string = "$STATE_DIRECTORY/datastore.sqlite3";
            };
            NodeAttestor.http_challenge.plugin_data.required_port = 80;
          };
        };
      };

      kubernetes.spire.server = {
        enable = true;
        entries = lib.mkMerge (lib.mapAttrsToList (_: node: node.kubernetes.spire.entries) nodes);
      };
    };

  # /etc/hosts lines that point spire.<domain> at the node running `server`.
  # Set on all nodes with defaults.networking.extraHosts.
  spireHosts = serverNode: ''
    ${serverNode.networking.primaryIPAddress} spire.example.com
    ${serverNode.networking.primaryIPv6Address} spire.example.com
  '';
}
