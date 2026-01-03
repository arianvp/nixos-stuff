{ lib, ... }:
{
  services.opentelemetry-collector.settings = {
    extensions."file_storage/journald-raw" = {
      directory = "\${env:STATE_DIRECTORY}/journald-raw";
      create_directory = true;
    };

    receivers."journald/raw" = {
      directory = "/var/log/journal";
      storage = "file_storage/journald-raw";
      start_at = "end";
      # No operators - no processing whatsoever
    };

    exporters."otlp/dash0-journald" = {
      endpoint = "ingress.europe-west4.gcp.dash0.com:4317";
      auth.authenticator = "bearertokenauth/dash0";
      headers."Dash0-Dataset" = "two";
    };

    service = {
      extensions = [ "file_storage/journald-raw" ];

      pipelines."logs/journald-raw" = {
        receivers = [ "journald/raw" ];
        exporters = [ "otlp/dash0-journald" ];
      };
    };
  };
}
