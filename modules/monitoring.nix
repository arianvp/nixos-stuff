{ config, ... }: {
  services.grafana = {
    enable = true;
    settings = {
      server.http_addr = "";
    };
    provision.enable = true;
    /*provision.datasources = {
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
    };*/
  };

  services.prometheus = {
    enable = true;
    alertmanagers = [{
      dns_sd_configs = [{ names = [ "alertmanager._http._tcp.local" ]; }];
    }];
    scrapeConfigs = [
      {
        job_name = "node_exporter";
        dns_sd_configs = [{ names = [ "node-exporter._http._tcp.local" ]; }];
      }
      {
        job_name = "prometheus";
        dns_sd_configs = [{ names = [ "prometheus._http._tcp.local" ]; }];
      }
      {
        job_name = "alertmanager";
        dns_sd_configs = [{ names = [ "alertmanager._http._tcp.local" ]; }];
      }
    ];

    structuredRules = {
      groups = [
        {
          name = "Prometheus";
          rules = [
            {
              alert = "PrometheusJobMissing";
              expr = "absent(up{job=\"prometheus\"})";
              for = "0m";
              labels = { severity = "warning"; };
              annotations = {
                summary = "Prometheus job missing (instance {{ $labels.instance }})";
                description = "A Prometheus job has disappeared\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
              };
            }
          ];
        }
      ];
    };

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

  systemd.dnssd.services = {
    prometheus = { type = "_http._tcp"; port = config.services.prometheus.port; };
    alertmanager = { type = "_http._tcp"; port = config.services.prometheus.alertmanager.port; };
    grafana = { type = "_http._tcp"; port = config.services.grafana.settings.server.http_port; };
    node-exporter = { type = "_http._tcp"; port = config.services.prometheus.exporters.node.port; };
  };


}
