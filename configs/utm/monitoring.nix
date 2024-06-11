
{
  services.grafana = {
    enable = true;
    settings = {
      server.http_addr = "";
    };
    provision.enable = true;
    provision.datasources = {
      settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://utm.local:${toString config.services.prometheus.port}";
        }
        {
          name = "AlertManager";
          type = "alertmanager";
          jsonData.implementation = "prometheus";
          url = "http://utm.local:${toString config.services.prometheus.alertmanager.port}";
        }
      ];
    };
  };
  services.prometheus = {
    enable = true;
    alertmanagers = [{
      dns_sd_configs = [{ names = [ "alertmanager._http._tcp.local" ]; }];
      static_configs = [{ targets = [ "utm.local:${toString config.services.prometheus.alertmanager.port}" ]; }];
    }];
    scrapeConfigs = [{
      job_name = "node_exporter";
      dns_sd_configs = [{ names = [ "node-exporter._http._tcp.local" ]; }];
      static_configs = [{ targets = [ "utm.local:${toString config.services.prometheus.exporters.node.port}" ]; }];
    }];
  };

  services.prometheus.alertmanager = {
    configuration = {
      receivers = [{
        name = "webhook";
        webhook_configs = [{ url = "https://webhook.site/5539afb0-089b-4c8f-a726-3187a72bd474"; }];
      }];
      route = {
        group_by = [ "cluster" "alertname" ];
        receiver = "webhook";
      };
    };
    enable = true;
  };
  services.prometheus.exporters.node.enable = true;
  environment.etc."systemd/dnssd/node-exporter.dnssd".text = ''
    [Service]
    Name=node-exporter
    Type=_http._tcp
    Port=${toString config.services.prometheus.exporters.node.port}
  '';
}