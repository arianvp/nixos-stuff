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
      # shellcheck disable=SC1091
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
    EnvironmentFile = "-/run/opentelemetry-collector-resource-attrs/resource-attrs.env";
  };
}
