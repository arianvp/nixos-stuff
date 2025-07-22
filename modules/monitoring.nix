{ config, ... }:
{
  services.prometheus.exporters.node.enable = true;
  services.prometheus.exporters.cgroup.enable = true;
  systemd.dnssd.services = {
    node-exporter = {
      type = "_http._tcp";
      port = config.services.prometheus.exporters.node.port;
    };
    cgroup-exporter = {
      type = "_http._tcp";
      port = config.services.prometheus.exporters.cgroup.port;
    };
  };
}
