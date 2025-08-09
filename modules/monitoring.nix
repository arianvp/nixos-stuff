{ pkgs, config, ... }:
{
  services.prometheus.exporters = {
    node.enable = true;
    cgroup.enable = true;
    smartctl.enable = true;
    smartctl.group = "disk";
    systemd.enable = true;
  };

  # workaround for upstream bug. it only does it on ADD
  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="nvme", KERNEL=="nvme[0-9]*", RUN+="${pkgs.acl}/bin/setfacl -m g:smartctl-exporter-access:rw /dev/$kernel"
  '';

  systemd.dnssd.services = {
    node-exporter = {
      type = "_http._tcp";
      port = config.services.prometheus.exporters.node.port;
    };
    systemd-exporter = {
      type = "_http._tcp";
      port = config.services.prometheus.exporters.systemd.port;
    };
    cgroup-exporter = {
      type = "_http._tcp";
      port = config.services.prometheus.exporters.cgroup.port;
    };
    smartctl-exporter = {
      type = "_http._tcp";
      port = config.services.prometheus.exporters.smartctl.port;
    };
  };
}
