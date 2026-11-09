# Shared setup for the Kubernetes tests: a SPIRE trust domain whose agents
# attest with their TPM, as in production. Each node's swtpm gets an EK
# certificate from the test CA whose TPM model is the node's host name, so a
# node alias selects it by tpm:model although its EK is new on every run.
{ lib }:
let
  # The node alias every workload of a node runs under
  nodeID = host: "spiffe://example.com/node/${host}";
in
{
  inherit nodeID;
  trustDomain = "example.com";
  domain = "example.com";

  # Every node: a SPIRE agent and the SPIRE wiring of the Kubernetes modules
  node =
    { config, pkgs, ... }:
    let
      hostName = config.networking.hostName;
    in
    {
      imports = [
        ./.
        ../tpm2-ekcert-provisioning.nix
      ];

      networking.domain = "example.com";
      networking.useNetworkd = true;
      # systemd-resolved mixes up the names of addresses that are on several
      # lines of /etc/hosts, as with names that resolve to several nodes
      system.nssDatabases.hosts = lib.mkBefore [ "files" ];

      virtualisation.useEFIBoot = true;
      virtualisation.tpm.provisioningRootCA = {
        enable = true;
        key = ../../tests/tpm-ca.key;
        certificate = ../../tests/tpm-ca.crt;
        model = hostName;
      };

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
            KeyManager.disk.plugin_data.directory = "$STATE_DIRECTORY";
            NodeAttestor.tpm = {
              plugin_cmd = lib.getExe' pkgs.spire-tpm-plugin "tpm_attestor_agent";
              plugin_data = { };
            };
            WorkloadAttestor.systemd.plugin_data = { };
            WorkloadAttestor.unix.plugin_data = { };
          };
        };
      };

      kubernetes.spire = {
        enable = true;
        parentID = nodeID hostName;
        entries."${hostName}-node" = {
          spiffeID = nodeID hostName;
          parentID = "spiffe://example.com/spire/server";
          selectors = [ "tpm:model:${hostName}" ];
        };
        # The test driver's shell
        admins.root = [ "systemd:id:backdoor.service" ];
      };
    };

  # The SPIRE server, which registers what every node asks for. Every node
  # needs spireHosts pointing at it.
  server =
    { nodes, pkgs, ... }:
    {
      environment.etc."spire/server/tpm-ca/tpm-ca.crt".source = ../../tests/tpm-ca.crt;
      services.spire.server = {
        enable = true;
        openFirewall = true;
        settings = {
          server.trust_domain = "example.com";
          plugins = {
            KeyManager.disk.plugin_data.keys_path = "$STATE_DIRECTORY/keys.json";
            DataStore.sql.plugin_data = {
              database_type = "sqlite3";
              connection_string = "$STATE_DIRECTORY/datastore.sqlite3";
            };
            NodeAttestor.tpm = {
              plugin_cmd = lib.getExe' pkgs.spire-tpm-plugin "tpm_attestor_server";
              plugin_data.ca_path = "/etc/spire/server/tpm-ca";
            };
          };
        };
      };

      kubernetes.spire.server = {
        enable = true;
        entries = lib.mkMerge (lib.mapAttrsToList (_: node: node.kubernetes.spire.entries) nodes);
      };
    };

  # OpenBao, which the API servers sign service account tokens with. The test
  # driver's shell is an admin in it, so it can rotate keys and read anything.
  openbao =
    { config, pkgs, ... }:
    let
      spiffeID = "spiffe://example.com/openbao/${config.networking.hostName}";
    in
    {
      spire.openbao = {
        enable = true;
        inherit spiffeID;
        # A real key would be encrypted with systemd-creds
        sealKey.file = "${pkgs.writeText "openbao-seal-key" "6b2c5f2a2a4e4c1f9d3e7b8a0c1d2e3f4a5b6c7d8e9f00112233445566778899"}";
        policies.admin = ''
          path "*" {
            capabilities = ["create", "read", "update", "delete", "list", "sudo"]
          }
        '';
        certRoles.admin = {
          allowedURISANs = [ "spiffe://example.com/k8s/admin/root" ];
          policies = [ "admin" ];
        };
      };
      kubernetes.spire.entries.openbao = {
        inherit spiffeID;
        selectors = [ "systemd:id:openbao-svid.service" ];
        dnsNames = [ config.networking.fqdn ];
      };
    };

  openbaoURL = host: "https://${host}.example.com:8200";

  # /etc/hosts lines that point spire.<domain> at the node running `server`.
  # Set on all nodes with defaults.networking.extraHosts.
  spireHosts = serverNode: ''
    ${serverNode.networking.primaryIPAddress} spire.example.com
    ${serverNode.networking.primaryIPv6Address} spire.example.com
  '';
}
