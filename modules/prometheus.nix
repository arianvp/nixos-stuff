{ lib, config, ... }:
{
  imports = [ ./prometheus-rules.nix ];

  # advertise the service on LAN
  systemd.dnssd.services.prometheus = {
    type = "_http._tcp";
    port = config.services.prometheus.port;
  };

  networking.firewall.allowedTCPPorts = [ config.services.prometheus.port ];

  services.prometheus = {
    enable = true;
    alertmanagers = [ { dns_sd_configs = [ { names = [ "alertmanager._http._tcp.local" ]; } ]; } ];
    globalConfig.scrape_interval = "15s";
    scrapeConfigs = [
      {
        job_name = "cgroup";
        dns_sd_configs = [ { names = [ "_cgroup_exporter._sub._http._tcp.local" ]; } ];
      }
      {
        job_name = "node";
        dns_sd_configs = [ { names = [ "_node_exporter._sub._http._tcp.local" ]; } ];
      }
      {
        job_name = "smartctl";
        dns_sd_configs = [ { names = [ "_smartctl_exporter._sub._http._tcp.local" ]; } ];
      }
      {
        job_name = "systemd";
        dns_sd_configs = [ { names = [ "_systemd_exporter._sub._http._tcp.local" ]; } ];
      }
      {
        job_name = "prometheus";
        dns_sd_configs = [ { names = [ "prometheus._http._tcp.local" ]; } ];
      }
      {
        job_name = "alertmanager";
        dns_sd_configs = [ { names = [ "alertmanager._http._tcp.local" ]; } ];
      }
    ];

    structuredRules = {
      # TODO: Groups?
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
              expr = ''absent(up{job=~"prometheus|alertmanager"})'';
              labels.severity = "warning";
              annotations = {
              };
            }
            {
              alert = "PrometheusAllTargetsMissing";
              expr = "sum by (job) (up) == 0";
              labels.severity = "critical";
            }

            {
              alert = "PrometheusConfigurationReloadFailure";
              expr = "prometheus_config_last_reload_successful != 1";
              labels.severity = "warning";
            }
            {
              alert = "AlertmanagerConfigurationReloadFailure";
              expr = "alertmanager_config_last_reload_successful != 1";
              labels.severity = "warning";
            }
          ]
          ++

            lib.pipe
              {
                metric = [
                  "memory"
                  "io"
                  "cpu"
                ];
                type = [
                  "stalled"
                  "waiting"
                ];
                threshold = [
                  60
                  90
                ];
              }
              [
                lib.cartesianProduct
                (map (
                  {
                    metric,
                    type,
                    threshold,
                  }:
                  {
                    alert = "${metric}_${type}_${toString threshold}";
                    expr = "rate(cgroup_${metric}_pressure_${type}_seconds_total[1m]) > ${toString (threshold / 100.0)}";
                    labels.severity =
                      if type == "waiting" then
                        "notice"
                      else if threshold == 60 then
                        "warning"
                      else
                        "critical";
                  }
                ))
              ];

        }
      ];
    };

  };
}
