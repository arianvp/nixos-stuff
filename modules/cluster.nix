{
  config,
  pkgs,
  lib,
  ...
}:
let
  vaultServers = 2;
  consulServers = 3;
  prefix = "10.231.136.";
  netmask = "24";

  vaultServerConfig = i: {
    name = "vault${toString i}";
    value = {
      config =
        { ... }:
        {
          imports = [ ./vault-server.nix ];
          config.services.vault-server.config = {
          };
        };
    };
  };
  consulServerConfig = i: {
    name = "consul${toString i}";
    value = {
      privateNetwork = true;
      hostBridge = "cl1";
      localAddress = "${prefix}${toString (i + 1)}/${netmask}";
      autoStart = true;
      config =
        { ... }:
        {
          imports = [ ./consul-agent.nix ];
          config.consul-agent.config = {
            bootstrap_expect = consulServers;
            server = true;
            retry_join = map (i: "${prefix}${toString (i + 1)}") (lib.range 1 consulServers);
          };
        };
    };
  };
in
{
  config = {
    containers = lib.listToAttrs (
      map consulServerConfig (lib.range 1 consulServers)
      ++ map vaultServerConfig (lib.range 1 vaultServers)
    );

    # The interfaces for this bridge are explicitly empty.
    # Each container will connect to the bridge
    networking.bridges.cl1.interfaces = [ ];
    networking.interfaces.cl1 = { };
  };
}
