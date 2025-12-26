{ lib, ... }:
{
  systemd.services.opentelemetry-collector.serviceConfig.LoadCredential = [ "dash0-api-key" ];

  services.opentelemetry-collector.settings = {
    extensions."bearertokenauth/dash0".filename = "\${env:CREDENTIALS_DIRECTORY}/dash0-api-key";

    exporters."otlp/dash0" = {
      endpoint = "ingress.europe-west4.gcp.dash0.com:4317";
      auth.authenticator = "bearertokenauth/dash0";
    };

    service = {
      extensions = [ "bearertokenauth/dash0" ];
      pipelines = {
        traces.exporters = [ "otlp/dash0" ];
        metrics.exporters = [ "otlp/dash0" ];
        logs.exporters = [ "otlp/dash0" ];
      };
    };
  };
}
