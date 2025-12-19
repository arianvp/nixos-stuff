{ pkgs, lib, config, ... }:
let
  # Convert hostnamectl JSON to shell-sourceable format (like /etc/machine-info)
  hostnamectlToEnv = pkgs.writeShellApplication {
    name = "hostnamectl-to-env";
    runtimeInputs = [ pkgs.jq config.systemd.package ];
    text = ''
      hostnamectl --json=pretty | jq -r '
        # Extract string fields and convert to UPPER_SNAKE_CASE
        to_entries |
        map(
          select(.value != null and .value != "" and (.value | type) == "string") |
          # Convert PascalCase to UPPER_SNAKE_CASE (e.g., HardwareVendor -> HARDWARE_VENDOR)
          .key |= (gsub("(?<a>[a-z])(?<b>[A-Z])"; "\(.a)_\(.b)") | ascii_upcase) |
          "\(.key)=\"\(.value)\""
        ) |
        .[] ;

        # Extract OperatingSystemReleaseData array and convert to shell variables
        .OperatingSystemReleaseData // [] |
        map(select(. != null and . != "")) |
        .[]
      '
    '';
  };

  hostnamectlToOtel = pkgs.writeShellApplication {
    name = "hostnamectl-to-otel";
    runtimeInputs = [ hostnamectlToEnv ];
    text = ''
      # Source hostnamectl info (includes os-release data from OperatingSystemReleaseData)
      eval "$(hostnamectl-to-env)"

      # Build OS attributes from os-release
      # Following https://opentelemetry.io/docs/specs/semconv/resource/os/
      os_attrs=""
      os_attrs="''${os_attrs}os.type=linux,"
      [ -n "''${NAME:-}" ] && os_attrs="''${os_attrs}os.name=$NAME,"
      [ -n "''${VERSION_ID:-}" ] && os_attrs="''${os_attrs}os.version=$VERSION_ID,"
      [ -n "''${BUILD_ID:-}" ] && os_attrs="''${os_attrs}os.build_id=$BUILD_ID,"
      [ -n "''${PRETTY_NAME:-}" ] && os_attrs="''${os_attrs}os.description=$PRETTY_NAME,"

      # Build host/device/deployment attributes from hostnamectl and os-release
      # Following https://opentelemetry.io/docs/specs/semconv/resource/host/
      # https://opentelemetry.io/docs/specs/semconv/resource/device/
      # https://opentelemetry.io/docs/specs/semconv/resource/deployment-environment/
      host_attrs=""
      [ -n "''${HOSTNAME:-}" ] && host_attrs="''${host_attrs}host.name=$HOSTNAME,"
      [ -n "''${MACHINE_ID:-}" ] && host_attrs="''${host_attrs}host.id=$MACHINE_ID,"
      [ -n "''${CHASSIS:-}" ] && host_attrs="''${host_attrs}host.type=$CHASSIS,"
      [ -n "''${ARCHITECTURE:-}" ] && host_attrs="''${host_attrs}host.arch=$ARCHITECTURE,"
      [ -n "''${IMAGE_ID:-}" ] && host_attrs="''${host_attrs}host.image.id=$IMAGE_ID,"
      [ -n "''${IMAGE_VERSION:-}" ] && host_attrs="''${host_attrs}host.image.version=$IMAGE_VERSION,"
      [ -n "''${HARDWARE_VENDOR:-}" ] && host_attrs="''${host_attrs}device.manufacturer=$HARDWARE_VENDOR,"
      [ -n "''${HARDWARE_MODEL:-}" ] && host_attrs="''${host_attrs}device.model.identifier=$HARDWARE_MODEL,"
      [ -n "''${DEPLOYMENT:-}" ] && host_attrs="''${host_attrs}deployment.environment.name=$DEPLOYMENT,"

      # Combine and remove trailing comma
      attrs="''${os_attrs}''${host_attrs}"
      attrs="''${attrs%,}"

      echo "OTEL_RESOURCE_ATTRIBUTES=$attrs"
    '';
  };
in
{
  systemd.services.opentelemetry-collector.serviceConfig = {
    LoadCredential = [
      "honeycomb-ingest-key"
      "grafana-cloud-basic-auth"
    ];
    ExecStartPre = "${hostnamectlToOtel}/bin/hostnamectl-to-otel > /run/opentelemetry-collector/resource-attrs.env";
    EnvironmentFile = "/run/opentelemetry-collector/resource-attrs.env";
    RuntimeDirectory = "opentelemetry-collector";
  };

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
          detectors = [ "env" ];
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

              # NOTE: host.name and host.id come from journal fields (_HOSTNAME, _MACHINE_ID)
              # which correctly identify the source (host/container/VM). We use the collector's
              # host info from resourcedetection/env for the physical collector host.
              # TODO: Figure out what to do with merged logs from containers. For now lets ignore
              # ''set(attributes["host.name"], body["_HOSTNAME"])''
              # ''set(attributes["host.id"], body["_MACHINE_ID"])''

              ''set(attributes["service.name"], body["_SYSTEMD_UNIT"])''
              ''set(attributes["service.instance.id"], body["_SYSTEMD_INVOCATION_ID"])''
            ];
          }];
        };
        "groupbyattrs/journal_semantic_conventions" = {
          keys = [
            "service.name"
            "service.instance.id"
            #  "host.name"
            # "host.id"
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
