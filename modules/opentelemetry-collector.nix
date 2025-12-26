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
        .[]
      '
    '';
  };

  hostnamectlToOtel = pkgs.writeShellApplication {
    name = "hostnamectl-to-otel";
    runtimeInputs = [ hostnamectlToEnv ];
    text = ''
      # Source os-release directly (properly quoted)
      . /etc/os-release

      # Source hostnamectl info
      eval "$(hostnamectl-to-env)"

      # Build OS attributes from os-release
      # Following https://opentelemetry.io/docs/specs/semconv/resource/os/
      os_attrs=""
      os_attrs="''${os_attrs}os.type=linux,"
      [ -n "''${NAME:-}" ] && os_attrs="''${os_attrs}os.name=''${NAME},"
      [ -n "''${VERSION_ID:-}" ] && os_attrs="''${os_attrs}os.version=''${VERSION_ID},"
      [ -n "''${BUILD_ID:-}" ] && os_attrs="''${os_attrs}os.build_id=''${BUILD_ID},"
      [ -n "''${PRETTY_NAME:-}" ] && os_attrs="''${os_attrs}os.description=''${PRETTY_NAME},"

      # Build host/device/deployment attributes from hostnamectl and os-release
      # Following https://opentelemetry.io/docs/specs/semconv/resource/host/
      # https://opentelemetry.io/docs/specs/semconv/resource/device/
      # https://opentelemetry.io/docs/specs/semconv/resource/deployment-environment/
      host_attrs=""
      [ -n "''${HOSTNAME:-}" ] && host_attrs="''${host_attrs}host.name=''${HOSTNAME},"
      [ -n "''${MACHINE_ID:-}" ] && host_attrs="''${host_attrs}host.id=''${MACHINE_ID},"
      [ -n "''${CHASSIS:-}" ] && host_attrs="''${host_attrs}host.type=''${CHASSIS},"
      [ -n "''${ARCHITECTURE:-}" ] && host_attrs="''${host_attrs}host.arch=''${ARCHITECTURE},"
      [ -n "''${IMAGE_ID:-}" ] && host_attrs="''${host_attrs}host.image.id=''${IMAGE_ID},"
      [ -n "''${IMAGE_VERSION:-}" ] && host_attrs="''${host_attrs}host.image.version=''${IMAGE_VERSION},"
      [ -n "''${HARDWARE_VENDOR:-}" ] && host_attrs="''${host_attrs}device.manufacturer=''${HARDWARE_VENDOR},"
      [ -n "''${HARDWARE_MODEL:-}" ] && host_attrs="''${host_attrs}device.model.identifier=''${HARDWARE_MODEL},"
      [ -n "''${DEPLOYMENT:-}" ] && host_attrs="''${host_attrs}deployment.environment.name=''${DEPLOYMENT},"

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
        "bearertokenauth/honeycomb" = {
          filename = "\${env:CREDENTIALS_DIRECTORY}/honeycomb-ingest-key";
          header = "x-honeycomb-team";
          scheme = "";
        };
        "bearertokenauth/dash0" = {
          filename = "\${env:CREDENTIALS_DIRECTORY}/dash0-api-key";
        };
        "bearertokenauth/grafana_cloud" = {
          filename = "\${env:CREDENTIALS_DIRECTORY}/grafana-cloud-basic-auth";
          scheme = "Basic";
        };
        "file_storage/journald" = {
          directory = "\${env:STATE_DIRECTORY}";
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
          storage = "file_storage/journald";
          start_at = "end";
          operators =
            let
              copy = from: to: {
                type = "copy";
                inherit from to;
                "if" = "${from} != nil";
              };
              copyAttr = from: to: copy from ''attributes["${to}"]'';
              copyResource = from: to: copy from ''resource["${to}"]'';
            in
            [
              # Log-level attributes (not resource attributes)
              (copyAttr "body.__CURSOR" "log.record.uid")
              {
                type = "severity_parser";
                parse_from = "body.PRIORITY";
                overwrite_text = true;
                mapping = {
                  debug = {
                    min = 7;
                    max = 7;
                  };
                  info = {
                    min = 6;
                    max = 6;
                  };
                  info2 = {
                    min = 5;
                    max = 5;
                  };
                  warn = {
                    min = 4;
                    max = 4;
                  };
                  error = {
                    min = 3;
                    max = 3;
                  };
                  error2 = {
                    min = 2;
                    max = 2;
                  };
                  error3 = {
                    min = 1;
                    max = 1;
                  };
                  fatal = {
                    min = 0;
                    max = 0;
                  };
                };
                "if" = "body.PRIORITY != nil";
              }

              (copyAttr "body.CODE_FILE" "code.filepath")
              (copyAttr "body.CODE_FUNC" "code.function")
              (copyAttr "body.CODE_LINE" "code.lineno")

              (copyAttr "body.TID" "thread.id")

              (copyAttr "body._TRANSPORT" "log.iostream")
              (copyAttr "body._STREAM_ID" "systemd.stream.id")

              # The message type
              # TODO: SemConv equiv?
              (copyAttr "body.MESSAGE_ID" "systemd.message.id")
              (copyAttr "body.ERRNO" "systemd.errno")

              # systemd
              (copyAttr "body.INVOCATION_ID" "systemd.invocation.id")
              (copyAttr "body.USER_INVOCATION_ID" "systemd.user.invocation.id")
              (copyAttr "body.UNIT" "systemd.unit")
              (copyAttr "body.USER_UNIT" "systemd.user.unit")

              # TODO: find semantic variant
              (copyAttr "body.DOCUMENTATION" "systemd.documentation")

              # delegated
              (copyAttr "body.OBJECT_PID" "process.pid")
              (copyAttr "body.OBJECT_CWD" "process.working_directory")
              (copyAttr "body.OBJECT_EXE" "process.executable.path")
              (copyAttr "body.OBJECT_CMDLINE" "process.command_line")
              (copyAttr "body.OBJECT_UID" "process.user.id")
              (copyAttr "body.OBJECT_GID" "process.group.id")
              (copyAttr "body.OBJECT_SYSTEMD_CGROUP" "process.linux.cgroup")
              # made this one up
              (copyAttr "body.OBJECT_CAP_EFFECTIVE" "process.capabilities.effective")
              (copyAttr "body.OBJECT_SYSTEMD_UNIT" "systemd.unit")
              (copyAttr "body.OBJECT_SYSTEMD_SLICE" "systemd.slice")
              (copyAttr "body.OBJECT_SYSTEMD_INVOCATION_ID" "systemd.invocation.id")

              (copyAttr "body.COREDUMP_PID" "process.pid")
              (copyAttr "body.COREDUMP_CWD" "process.working_directory")
              (copyAttr "body.COREDUMP_COMM" "process.executable.name")
              (copyAttr "body.COREDUMP_EXE" "process.executable.path")
              (copyAttr "body.COREDUMP_CMDLINE" "process.command_line")
              (copyAttr "body.COREDUMP_UID" "process.user.id")
              (copyAttr "body.COREDUMP_GID" "process.group.id")
              (copyAttr "body.COREDUMP_CGROUP" "process.linux.cgroup")
              (copyAttr "body.COREDUMP_UNIT" "systemd.unit")

              (copyAttr "body.COREDUMP_SLICE" "systemd.slice")

              # COREDUMP_SIGNAL_NAME
              # COREDUMP_SIGNAL
              # COREDUMP_CONTAINER_CMDLINE
              # COREDUMP_HOSTNAME
              # COREDUMP_TIMESTAMP
              # NOTE: Bit of a bitch to map to https://opentelemetry.io/docs/specs/semconv/registry/attributes/process/#process-environment-variable due to it not being a map
              # COREDUMP_ENVIRON

              # Resource attributes - process
              (copyResource "body._PID" "process.pid")
              (copyResource "body._UID" "process.user.id")
              (copyResource "body._GID" "process.group.id")
              (copyResource "body._EXE" "process.executable.path")
              (copyResource "body._COMM" "process.executable.name")
              (copyResource "body._CMDLINE" "process.command_line")
              (copyResource "body._CAP_EFFECTIVE" "process.capabilities.effective")
              (copyResource "body._SYSTEMD_CGROUP" "process.linux.cgroup")

              (copyResource "body._SYSTEMD_CGROUP" "systemd.cgroup")
              (copyResource "body._SYSTEMD_SLICE" "systemd.slice")
              (copyResource "body._SYSTEMD_INVOCATION_ID" "systemd.invocation_id")
              (copyResource "body._SYSTEMD_UNIT" "systemd.unit")

              # TODO: Do we actually set service.name? And should we set it to SYSLOG_IDENTIFIER?

              /*
                (copyResource "body._SYSTEMD_UNIT" "service.name")
                {
                  type = "move";
                  from = "body.SYSLOG_IDENTIFIER";
                  to = ''resource["service.name"]'';
                  "if" = ''body.SYSLOG_IDENTIFIER != nil && resource["service.name"] == nil'';
                }
                (copyResource "body._SYSTEMD_INVOCATION_ID" "service.instance.id")
              */

              {
                type = "move";
                from = "body";
                to = ''attributes["log.record.original"]'';
              }
              {
                type = "copy";
                from = ''attributes["log.record.original"]["MESSAGE"]'';
                to = "body";
              }
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
          auth.authenticator = "bearertokenauth/honeycomb";
        };
        "otlp/dash0" = {
          endpoint = "ingress.europe-west4.gcp.dash0.com:4317";
          auth.authenticator = "bearertokenauth/dash0";
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
          "file_storage/journald"
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
              "otlp/dash0"
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
              "otlp/dash0"
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
            processors = [
              "resourcedetection"
              "batch"
            ];
            exporters = [
              "otlp/honeycomb"
              "otlphttp/grafana_cloud"
              "otlp/dash0"
            ];
          };
        };
      };
    };
  };
}
