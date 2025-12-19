{ pkgs, ... }:
{
  systemd.services.opentelemetry-collector.serviceConfig.LoadCredential = [
    "honeycomb-ingest-key"
    "grafana-cloud-basic-auth"
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
        "bearertokenauth/grafana_cloud" = {
          filename = "\${env:CREDENTIALS_DIRECTORY}/grafana-cloud-basic-auth";
          scheme = "Basic";
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
              ''set(attributes["deployment.environment"], resource.attributes["deployment.environment"])''
              ''set(attributes["service.version"], resource.attributes["service.version"])''
            ];
          }];
        };
        "transform/journal_semantic_conventions" = {
          error_mode = "ignore";
          log_statements = [{
            context = "log";
            statements = [
              # Unique identifier (log attribute)
              ''set(attributes["log.record.uid"], body["__CURSOR"])''

              # Log severity (log attribute)
              ''set(attributes["log.severity_number"], body["PRIORITY"])''

              # Code location attributes (log attributes)
              ''set(attributes["code.filepath"], body["CODE_FILE"])''
              ''set(attributes["code.function"], body["CODE_FUNC"])''
              ''set(attributes["code.lineno"], body["CODE_LINE"])''

              # Thread ID (log attribute)
              ''set(attributes["thread.id"], body["TID"])''

              # Extract to attributes first, groupbyattrs will promote to resource
              ''set(attributes["process.pid"], body["_PID"])''
              ''set(attributes["process.executable.path"], body["_EXE"])''
              ''set(attributes["process.executable.name"], body["_COMM"])''
              ''set(attributes["process.command_line"], body["_CMDLINE"])''
              ''set(attributes["process.linux.cgroup"], body["_SYSTEMD_CGROUP"])''

              ''set(attributes["host.name"], body["_HOSTNAME"])''
              ''set(attributes["host.id"], body["_MACHINE_ID"])''

              ''set(attributes["service.name"], body["_SYSTEMD_UNIT"])''
              ''set(attributes["service.instance.id"], body["_SYSTEMD_INVOCATION_ID"])''
            ];
          }];
        };
        "groupbyattrs/journal_semantic_conventions" = {
          keys = [
            "service.name"
            "service.instance.id"
            "host.name"
            "host.id"
            "process.pid"
            "process.executable.path"
            "process.executable.name"
            "process.command_line"
            "process.linux.cgroup"
          ];
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
          auth.authenticator = "bearertokenauth/grafana_cloud";
        };
      };

      # Service configuration
      service = {
        extensions = [ "bearertokenauth" "bearertokenauth/grafana_cloud" ];
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
            processors = [ "transform/journal_semantic_conventions" "groupbyattrs/journal_semantic_conventions" "batch" ];
            exporters = [ "otlp/honeycomb" "otlphttp/grafana_cloud" ];
          };
        };
      };
    };
  };
}
