{ pkgs, ... }:
{
  systemd.services.opentelemetry-collector.serviceConfig.LoadCredential = [
    "honeycomb-ingest-key"
    "grafana-cloud-token"
  ];

  services.opentelemetry-collector = {
    enable = true;
    package = pkgs.opentelemetry-collector-contrib;
    settings = {
      # Extensions for authentication
      extensions = {
        bearertokenauth = {
          filename = "\${env:CREDENTIALS_DIRECTORY}/honeycomb-ingest-key";
          header = "x-honeycomb-team";
          scheme = "";
        };
        "basicauth/grafana_cloud" = {
          client_auth = {
            username = "1473963";
            password = "\${env:CREDENTIALS_DIRECTORY}/grafana-cloud-token";
          };
        };
      };

      # Connectors
      connectors.grafanacloud = {
        host_identifiers = [ "host.name" ];
      };

      # Receivers
      receivers = {
        otlp = {
          protocols = {
            grpc = {};
            http = {};
          };
        };
        journald = {
          directory = "/var/log/journal";
        };
        hostmetrics = {
          scrapers = {
            cpu = {};
            disk = {};
            load = {};
            memory = {};
            filesystem = {};
            network = {};
            system = {};
          };
        };
      };

      # Processors
      processors = {
        batch = {};
        resourcedetection = {
          detectors = [ "system" "env" ];
          system.hostname_sources = [ "os" ];
          override = false;
        };
        "transform/add_resource_attributes_as_metric_attributes" = {
          error_mode = "ignore";
          metric_statements = [{
            context = "datapoint";
            statements = [
              "set(attributes[\"deployment.environment\"], resource.attributes[\"deployment.environment\"])"
              "set(attributes[\"service.version\"], resource.attributes[\"service.version\"])"
            ];
          }];
        };
      };

      # Exporters
      exporters = {
        "otlp/honeycomb" = {
          endpoint = "api.eu1.honeycomb.io:443";
          auth.authenticator = "bearertokenauth";
        };
        "otlphttp/grafana_cloud" = {
          endpoint = "https://otlp-gateway-prod-eu-west-2.grafana.net/otlp";
          auth.authenticator = "basicauth/grafana_cloud";
        };
      };

      # Service configuration
      service = {
        extensions = [ "bearertokenauth" "basicauth/grafana_cloud" ];
        pipelines = {
          # Traces pipeline
          traces = {
            receivers = [ "otlp" ];
            processors = [ "resourcedetection" "batch" ];
            exporters = [ "otlp/honeycomb" "otlphttp/grafana_cloud" "grafanacloud" ];
          };
          # Metrics pipeline
          metrics = {
            receivers = [ "otlp" "hostmetrics" ];
            processors = [ "resourcedetection" "transform/add_resource_attributes_as_metric_attributes" "batch" ];
            exporters = [ "otlp/honeycomb" "otlphttp/grafana_cloud" ];
          };
          # Grafana Cloud specific metrics pipeline
          "metrics/grafanacloud" = {
            receivers = [ "grafanacloud" ];
            processors = [ "batch" ];
            exporters = [ "otlphttp/grafana_cloud" ];
          };
          # Logs pipeline
          logs = {
            receivers = [ "otlp" "journald" ];
            processors = [ "resourcedetection" "batch" ];
            exporters = [ "otlp/honeycomb" "otlphttp/grafana_cloud" ];
          };
        };
      };
    };
  };
}
