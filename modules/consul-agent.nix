{
  config,
  options,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.consul-agent;
  agentConfig = pkgs.writeText "consul-agent.json" (builtins.toJSON cfg.config);
in
{
  options.consul-agent = {
    config = lib.options.mkOption {
      type = lib.types.attrs;
      description = "Consul config. See consul documentation for syntax";
      default = { };
    };
  };
  config = {
    environment.systemPackages = [ pkgs.consul ];
    networking.firewall = {
      allowedTCPPorts = [
        8300
        8301
        8302
        8500
        8600
      ];
      allowedUDPPorts = [
        8301
        3802
        8600
      ];
    };
    systemd.services.consul-agent = {
      wantedBy = [ "multi-user.target" ];
      unitConfig = {
      };
      serviceConfig = {
        ExecStart = "${pkgs.consul}/bin/consul agent -data-dir %T/consul -config-file ${agentConfig}";
        StateDirectory = "consul";
        Type = "notify";
      };
    };
  };
}
