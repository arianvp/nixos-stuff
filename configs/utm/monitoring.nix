{ pkgs, config, ... }:
{

  imports = [ ./dnssd.nix  ./systemd-utils.nix ../../modules/workload.nix ];

  systemd.services.grafana.serviceConfig.Slice = "workload.slice";
  systemd.services.prometheus.serviceConfig.Slice = "workload.slice";
  systemd.services.alertmanager.serviceConfig.Slice = "workload.slice";
  systemd.services."prometheus-node-exporter".serviceConfig.Slice = "workload.slice";

  services.grafana = {
    enable = true;
    settings.server.http_addr = "";
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

    rules = [
      ''
        groups:
          - name: Prometheus
            rules:
              - alert: PrometheusJobMissing
                expr: absent(up{job="prometheus"})
                for: 0m
                labels:
                  severity: warning
                annotations:
                  summary: Prometheus job missing (instance {{ $labels.instance }})
                  description: "A Prometheus job has disappeared\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}"
      ''
    ];

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


  /*systemd.services.socket-activated = {
    listenStream = [ "9999" ];
    unitConfig = {
      Requires = [ "not-socket-activated.service" ];
      After = [ "not-socket-activated.service" ];
    };
    serviceConfig = {
      Type = "notify";
      ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd 127.0.0.1:8000";
    };
  };*/
  systemd.socketProxies.not-socket-activated = {
    listenStream = [ "9999" ];
    address =  "127.0.0.1:8000";
  };
  systemd.services.not-socket-activated =
    let
      slowDaemon = pkgs.writeShellApplication {
        name = "slow-daemon";
        runtimeInputs = [ pkgs.coreutils pkgs.python3 ];
        text = ''
          sleep 5
          exec python3 -m http.server
        '';
      };
      waitSlowDaemonRunning = pkgs.writeShellApplication {
        name = "wait-slow-daemon-running";
        runtimeInputs = [ pkgs.coreutils pkgs.curl ];
        text = ''
          while ! curl -s http://localhost:8000 ; do
            sleep 1
          done
        '';
      };
    in
    {
      serviceConfig = {
        ExecStart = "${slowDaemon}/bin/slow-daemon";
        ExecStartPost = "${waitSlowDaemonRunning}/bin/wait-slow-daemon-running";
      };
    };
}
