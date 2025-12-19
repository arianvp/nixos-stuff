{
  pkgs,
  lib,
  config,
  ...
}:
let
  # Convert hostnamectl JSON to shell-sourceable format (like /etc/machine-info)
  hostnamectlToEnv = pkgs.writeShellApplication {
    name = "hostnamectl-to-env";
    runtimeInputs = [
      pkgs.jq
      config.systemd.package
    ];
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

      echo "OTEL_RESOURCE_ATTRIBUTES=$attrs" > /run/opentelemetry-collector-resource-attrs/resource-attrs.env
    '';
  };
in
{
  # Oneshot service to generate OTEL resource attributes from hostnamectl
  systemd.services.opentelemetry-collector-resource-attrs = {
    description = "Generate OpenTelemetry Collector Resource Attributes";
    wantedBy = [ "opentelemetry-collector.service" ];
    before = [ "opentelemetry-collector.service" ];
    serviceConfig = {
      Type = "oneshot";
      RuntimeDirectory = "opentelemetry-collector-resource-attrs";
      ExecStart = "${hostnamectlToOtel}/bin/hostnamectl-to-otel";
      RemainAfterExit = true;
    };
  };

  systemd.services.opentelemetry-collector.serviceConfig = {
    LoadCredential = [
      "honeycomb-ingest-key"
      "grafana-cloud-basic-auth"
    ];
    EnvironmentFile = "-/run/opentelemetry-collector-resource-attrs/resource-attrs.env";
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
            grpc = { };
            http = { };
          };
        };
        journald = {
          directory = "/var/log/journal";
          operators =
             let
               move = from: to: { type = "move"; inherit from to; "if" = "${from} != nil"; };
               moveAttr = from: to:  move from ''attributes["${to}"]'';
               moveResource = from: to: move from ''resource["${to}"]'';
               in
          [
            # Log-level attributes (not resource attributes)
            (moveAttr "body.__CURSOR" "log.record.uid")
            {
              type = "severity_parser";
              parse_from = "body.PRIORITY";
              to = ''attributes["log.severity_number"]'';
              mapping = {
               debug = 7;
               info = 6;
               info2 = 5;
               warn = 4;
               error = 3;
               error2 = 2;
               error3 = 1;
               fatal = 0;
              };
              "if" = "body.PRIORITY != nil";
            }
            (moveAttr "body.CODE_FILE" "code.filepath")
            (moveAttr "body.CODE_FUNC" "code.function")
            (moveAttr "body.CODE_LINE" "code.lineno")
            (moveAttr "body.TID" "thread.id")

            # Resource attributes - process
            (moveResource "body._PID" "process.pid")
            (moveResource "body._EXE" "process.executable.path")
            (moveResource "body._COMM" "process.executable.name")
            (moveResource "body._CMDLINE" "process.command_line")
            (moveResource "body._SYSTEMD_CGROUP" "process.linux.cgroup")
            (moveResource "body._SYSTEMD_UNIT" "service.name")
            {
              type = "move";
              from = "body.SYSLOG_IDENTIFIER";
              to = ''resource["service.name"]'';
              "if" = ''body.SYSLOG_IDENTIFIER != nil && resource["service.name"] == nil'';
            }
            (moveResource "body._SYSTEMD_INVOCATION_ID" "service.instance.id")

            # TODO: Perhaps use STREAM_ID with recombine?
            # https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/pkg/stanza/docs/operators/recombine.md

            # Move MESSAGE to body (do this last)
            # { type = "move"; from = "body.MESSAGE"; to = "body"; }
          ];
        };
        hostmetrics = {
          scrapers = {
            cpu = { };
            disk = { };
            load = { };
            memory = { };
            filesystem = { };
            network = { };
            system = { };
          };
        };
      };

      # Processors
      processors = {
        batch = { };
        resourcedetection = {
          detectors = [ "env" ];
          override = false;
        };
        "transform/add_resource_attributes_as_metric_attributes" = {
          error_mode = "ignore";
          metric_statements = [
            {
              context = "datapoint";
              statements = [
                ''set(attributes["deployment.environment"], resource.attributes["deployment.environment"])''
                ''set(attributes["service.version"], resource.attributes["service.version"])''
              ];
            }
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
        extensions = [
          "bearertokenauth"
          "bearertokenauth/grafana_cloud"
        ];
        pipelines = {
          # Traces pipeline
          traces = {
            receivers = [ "otlp" ];
            processors = [
              "resourcedetection"
              "batch"
            ];
            exporters = [
              "otlp/honeycomb"
              "otlphttp/grafana_cloud"
              "grafanacloud"
            ];
          };
          # Metrics pipeline
          metrics = {
            receivers = [
              "otlp"
              "hostmetrics"
            ];
            processors = [
              "resourcedetection"
              "transform/add_resource_attributes_as_metric_attributes"
              "batch"
            ];
            exporters = [
              "otlp/honeycomb"
              "otlphttp/grafana_cloud"
            ];
          };
          # Grafana Cloud specific metrics pipeline
          "metrics/grafanacloud" = {
            receivers = [ "grafanacloud" ];
            processors = [ "batch" ];
            exporters = [ "otlphttp/grafana_cloud" ];
          };
          # Logs pipeline
          logs = {
            receivers = [
              "otlp"
              "journald"
            ];
            processors = [ "batch" ];
            exporters = [
              "otlp/honeycomb"
              "otlphttp/grafana_cloud"
            ];
          };
        };
      };
    };
  };
}
