{ config, ... }: {
  services.netdata ={
    enable = true;
    config = {
      plugins = {
        systemd-journal = "yes";
      };
    };
  };
  services.grafana = {
    enable = true;
    settings = {
      server.http_addr = "";
      server.domain = "framework.local";
    };
    provision.enable = true;
    provision.datasources = {
      settings.deleteDatasources = [
        /*{
          name = "AlertManager";
          orgId = 1;
        }*/
      ];
      settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          # TODO: SD
          url = "http://localhost:${toString config.services.prometheus.port}";
        }
        {
          name = "AlertManager";
          type = "alertmanager";
          jsonData.implementation = "prometheus";
          jsonData.handleGrafanaManagedAlerts = true;
          # TODO: SD
          url = "http://localhost:${toString config.services.prometheus.alertmanager.port}";
        }
      ];
    };
  };

  services.prometheus = {
    enable = true;
    alertmanagers = [{
      dns_sd_configs = [{ names = [ "alertmanager._http._tcp.local" ]; }];
    }];
    globalConfig.scrape_interval = "15s";
    scrapeConfigs = [
      {
        job_name = "cgroups";
        dns_sd_configs = [{ names = [ "cgroup-exporter._http._tcp.local" ]; }];
      }
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
              alert = "DeadMansSwitch";
              expr = "vector(1)";
              labels.severity = "none";
              annotations = {
                summary = "DeadMansSwitch";
                description = "This is a DeadMansSwitch";
              };
            }
            {
              alert = "PrometheusJobMissing";
              expr = ''absent(up{job="prometheus"})'';
              labels.severity = "warning";
              annotations = {
                summary = "Prometheus job missing (instance {{ $labels.instance }})";
                description = "A Prometheus job has disappeared\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}";
              };
            }
            {
              alert = "MemoryStalled60";
              expr = "rate(cgroup_memory_pressure_stalled_seconds[1m]) > 0.6";
              labels.severity = "warning";
              annotations = {
                summary = "Memory pressure stalled for 60% of the time";
              };
            }
            {
              alert = "MemoryStalled90";
              expr = "rate(cgroup_memory_pressure_stalled_seconds[1m]) > 0.9";
              labels.severity = "critical";
              annotations = {
                summary = "Memory stalled for 90% of the time";
              };
            }
            {
              alert = "IOStalled60";
              expr = "rate(cgroup_io_pressure_stalled_seconds[1m]) > 0.6";
              labels.severity = "warning";
              annotations = {
                summary = "IO pressure stalled for 60% of the time";
              };
            }
            {
              alert = "IOStalled90";
              expr = "rate(cgroup_io_pressure_stalled_seconds[1m]) > 0.9";
              labels.severity = "critical";
              annotations = {
                summary = "IO stalled for 90% of the time";
              };
            }
            {
              alert = "CPUStalled60";
              expr = "rate(cgroup_cpu_pressure_stalled_seconds[1m]) > 0.6";
              labels.severity = "warning";
              annotations = {
                summary = "CPU pressure stalled for 60% of the time";
              };
            }
            {
              alert = "CPUStalled60";
              expr = "rate(cgroup_cpu_pressure_stalled_seconds[1m]) > 0.6";
              labels.severity = "critical";
              annotations = {
                summary = "CPU stalled for 60% of the time";
              };
            }
            {
              alert = "CPUStalled90";
              expr = "rate(cgroup_cpu_pressure_stalled_seconds[1m]) > 0.9";
              labels.severity = "critical";
              annotations = {
                summary = "CPU stalled for 90% of the time";
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
        webhook_configs = [{ url = "https://webhook.site/e26048d0-866a-4722-adda-06c9b65d8f32"; }];
      }];
      route = {
        group_by = [ "cluster" "alertname" ];
        receiver = "webhook";
      };
    };
    enable = true;
  };

  services.prometheus.exporters.node.enable = true;
  services.prometheus.exporters.cgroup.enable = true;

  systemd.dnssd.services = {
    prometheus = { type = "_http._tcp"; port = config.services.prometheus.port; };
    alertmanager = { type = "_http._tcp"; port = config.services.prometheus.alertmanager.port; };
    grafana = { type = "_http._tcp"; port = config.services.grafana.settings.server.http_port; };
    node-exporter = { type = "_http._tcp"; port = config.services.prometheus.exporters.node.port; };
    cgroup-exporter = { type = "_http._tcp"; port = config.services.prometheus.exporters.cgroup.port; };
  };


}
