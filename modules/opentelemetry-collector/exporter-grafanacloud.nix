{
  systemd.services.opentelemetry-collector.serviceConfig.LoadCredential = [ "grafana-cloud-basic-auth" ];

  services.opentelemetry-collector.settings = {
    extensions."bearertokenauth/grafana_cloud" = {
      filename = "\${env:CREDENTIALS_DIRECTORY}/grafana-cloud-basic-auth";
      scheme = "Basic";
    };

    connectors.grafanacloud = {
      host_identifiers = [ "host.name" ];
    };

    exporters."otlphttp/grafana_cloud" = {
      endpoint = "https://otlp-gateway-prod-eu-west-2.grafana.net/otlp";
      auth.authenticator = "bearertokenauth/grafana_cloud";
    };

    service = {
      extensions = [ "bearertokenauth/grafana_cloud" ];
      pipelines = {
        traces.exporters = [ "otlphttp/grafana_cloud" "grafanacloud" ];
        metrics.exporters = [ "otlphttp/grafana_cloud" ];
        logs.exporters = [ "otlphttp/grafana_cloud" ];
        "metrics/grafanacloud" = {
          receivers = [ "grafanacloud" ];
          processors = [ "batch" ];
          exporters = [ "otlphttp/grafana_cloud" ];
        };
      };
    };
  };
}
