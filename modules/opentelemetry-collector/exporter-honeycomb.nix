{ ... }:
{
  systemd.services.opentelemetry-collector.serviceConfig = {
    LoadCredential = [ "honeycomb-ingest-key" ];
  };

  services.opentelemetry-collector.settings = {
    extensions."bearertokenauth/honeycomb" = {
      filename = "\${env:CREDENTIALS_DIRECTORY}/honeycomb-ingest-key";
      header = "x-honeycomb-team";
      scheme = "";
    };

    exporters."otlp/honeycomb" = {
      endpoint = "api.eu1.honeycomb.io:443";
      auth.authenticator = "bearertokenauth/honeycomb";
    };

    service = {
      extensions = [ "bearertokenauth/honeycomb" ];
      pipelines = {
        traces.exporters = [ "otlp/honeycomb" ];
        metrics.exporters = [ "otlp/honeycomb" ];
        logs.exporters = [ "otlp/honeycomb" ];
      };
    };
  };
}
